// rods/ml/ai_facade — AI / transformer parity surface (attention, KV cache, RoPE, generation)
//
import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/math_facade.nr"
import "stdlib/rods/ml/nn_facade.nr"

// ai_facade.nr - first transformer-oriented kernels for the AI/LLM path.

#[repr(C)]
struct KvCacheF64 {
    keys: TensorF64,
    values: TensorF64
}

#[repr(C)]
struct TopKF64 {
    values: TensorF64,
    indices: TensorI64
}

#[repr(C)]
struct TopPF64 {
    probabilities: TensorF64,
    indices: TensorI64,
    counts: TensorI64
}

#[repr(C)]
struct DecodeStepF64 {
    hidden: TensorF64,
    logits: TensorF64,
    probabilities: TensorF64,
    greedy_tokens: TensorI64,
    top_values: TensorF64,
    top_indices: TensorI64
}

#[repr(C)]
struct SampledGenerationStepF64 {
    last_tokens: TensorI64,
    hidden: TensorF64,
    logits: TensorF64,
    probabilities: TensorF64,
    filtered_probabilities: TensorF64,
    sampled_tokens: TensorI64,
    output_token_ids: TensorI64
}

#[repr(C)]
struct GeneratedTokensI64 {
    token_ids: TensorI64,
    sampled_tokens: TensorI64
}

#[repr(C)]
struct LmHeadWeightsF64 {
    weight: TensorF64,
    bias: TensorF64
}

#[repr(C)]
struct TransformerDecoderLayerWeightsF64 {
    attn_ln_weight: TensorF64,
    attn_ln_bias: TensorF64,
    q_weight: TensorF64,
    q_bias: TensorF64,
    k_weight: TensorF64,
    k_bias: TensorF64,
    v_weight: TensorF64,
    v_bias: TensorF64,
    attn_out_weight: TensorF64,
    attn_out_bias: TensorF64,
    ff_ln_weight: TensorF64,
    ff_ln_bias: TensorF64,
    ff_w1: TensorF64,
    ff_b1: TensorF64,
    ff_w2: TensorF64,
    ff_b2: TensorF64
}

#[repr(C)]
struct DecoderLmHeadGreedyStepF64 {
    input_embeddings: TensorF64,
    hidden: TensorF64,
    logits: TensorF64,
    greedy_tokens: TensorI64,
    output_token_ids: TensorI64
}

fn ai_concat_rows_f64(a: &TensorF64, b: &TensorF64) -> TensorF64 {
    if a.shape.cols != b.shape.cols {
        print("ai error: concat rows requires equal column counts");
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(a) {
        data.push(a.data[i]);
        i = i + 1;
    };
    i = 0;
    while i < tensor_f64_len(b) {
        data.push(b.data[i]);
        i = i + 1;
    };
    return tensor_f64_from_vec(a.shape.rows + b.shape.rows, a.shape.cols, data);
}

fn ai_kv_cache_append_f64(cache_key: &TensorF64, cache_value: &TensorF64, next_key: &TensorF64, next_value: &TensorF64) -> KvCacheF64 {
    if cache_key.shape.rows != cache_value.shape.rows {
        print("ai error: cached key/value rows must match");
        return KvCacheF64 { keys: tensor_f64_zeros(0, 0), values: tensor_f64_zeros(0, 0) };
    };
    if next_key.shape.rows != next_value.shape.rows {
        print("ai error: next key/value rows must match");
        return KvCacheF64 { keys: tensor_f64_zeros(0, 0), values: tensor_f64_zeros(0, 0) };
    };
    return KvCacheF64 {
        keys: ai_concat_rows_f64(cache_key, next_key),
        values: ai_concat_rows_f64(cache_value, next_value)
    };
}

fn ai_token_embedding_f64(embedding: &TensorF64, token_ids: &TensorI64) -> TensorF64 {
    return tensor_f64_select_rows(embedding, token_ids);
}

fn ai_token_position_embedding_f64(token_embedding: &TensorF64, position_embedding: &TensorF64, token_ids: &TensorI64) -> TensorF64 {
    if token_embedding.shape.cols != position_embedding.shape.cols {
        print("ai error: token and position embedding dimensions must match");
        return tensor_f64_zeros(0, 0);
    };
    if token_ids.shape.cols > position_embedding.shape.rows {
        print("ai error: sequence length exceeds position embedding rows");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < token_ids.shape.rows {
        let mut c: i64 = 0;
        while c < token_ids.shape.cols {
            let token_id: i64 = tensor_i64_at(token_ids, r, c);
            if token_id < 0 || token_id >= token_embedding.shape.rows {
                print("ai error: token id outside embedding rows");
                return tensor_f64_zeros(0, 0);
            };
            let mut d: i64 = 0;
            while d < token_embedding.shape.cols {
                data.push(tensor_f64_at(token_embedding, token_id, d) + tensor_f64_at(position_embedding, c, d));
                d = d + 1;
            };
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(token_ids.shape.rows * token_ids.shape.cols, token_embedding.shape.cols, data);
}

fn ai_last_token_i64(token_ids: &TensorI64) -> TensorI64 {
    if token_ids.shape.cols <= 0 {
        print("ai error: token ids must have at least one column");
        return tensor_i64_zeros(0, 0);
    };

    let mut data: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < token_ids.shape.rows {
        data.push(tensor_i64_at(token_ids, r, token_ids.shape.cols - 1));
        r = r + 1;
    };
    return tensor_i64_from_vec(token_ids.shape.rows, 1, data);
}

fn ai_lm_head_logits_f64(hidden: &TensorF64, lm_head_weight: &TensorF64, lm_head_bias: &TensorF64) -> TensorF64 {
    return nn_linear_f64(hidden, lm_head_weight, lm_head_bias);
}

fn ai_last_row_f64(hidden: &TensorF64) -> TensorF64 {
    if hidden.shape.rows <= 0 {
        print("ai error: hidden sequence must have at least one row");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let row: i64 = hidden.shape.rows - 1;
    let mut c: i64 = 0;
    while c < hidden.shape.cols {
        data.push(tensor_f64_at(hidden, row, c));
        c = c + 1;
    };
    return tensor_f64_from_vec(1, hidden.shape.cols, data);
}

fn ai_sequence_lm_head_last_logits_f64(hidden: &TensorF64, lm_head_weight: &TensorF64, lm_head_bias: &TensorF64) -> TensorF64 {
    let last_hidden: TensorF64 = ai_last_row_f64(hidden);
    return ai_lm_head_logits_f64(&last_hidden, lm_head_weight, lm_head_bias);
}

fn ai_lm_head_logits_from_weights_f64(hidden: &TensorF64, lm_head: &LmHeadWeightsF64) -> TensorF64 {
    return ai_lm_head_logits_f64(hidden, &lm_head.weight, &lm_head.bias);
}

fn ai_sequence_lm_head_last_logits_from_weights_f64(hidden: &TensorF64, lm_head: &LmHeadWeightsF64) -> TensorF64 {
    let last_hidden: TensorF64 = ai_last_row_f64(hidden);
    return ai_lm_head_logits_from_weights_f64(&last_hidden, lm_head);
}

fn ai_greedy_next_token_i64(logits: &TensorF64) -> TensorI64 {
    return tensor_f64_argmax_axis1(logits);
}

fn ai_append_next_token_i64(token_ids: &TensorI64, next_tokens: &TensorI64) -> TensorI64 {
    if token_ids.shape.rows != next_tokens.shape.rows {
        print("ai error: token rows must match for append");
        return tensor_i64_zeros(0, 0);
    };
    if next_tokens.shape.cols != 1 {
        print("ai error: next_tokens must be shaped rows x 1");
        return tensor_i64_zeros(0, 0);
    };

    let out_cols: i64 = token_ids.shape.cols + 1;
    let mut data: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < token_ids.shape.rows {
        let mut c: i64 = 0;
        while c < token_ids.shape.cols {
            data.push(tensor_i64_at(token_ids, r, c));
            c = c + 1;
        };
        data.push(tensor_i64_at(next_tokens, r, 0));
        r = r + 1;
    };
    return tensor_i64_from_vec(token_ids.shape.rows, out_cols, data);
}

fn ai_clone_token_ids_i64(token_ids: &TensorI64) -> TensorI64 {
    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_i64_len(token_ids) {
        data.push(token_ids.data[i]);
        i = i + 1;
    };
    return tensor_i64_from_vec(token_ids.shape.rows, token_ids.shape.cols, data);
}

fn ai_threshold_column_f64(thresholds: &TensorF64, col: i64) -> TensorF64 {
    if col < 0 || col >= thresholds.shape.cols {
        print("ai error: threshold column outside matrix");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < thresholds.shape.rows {
        data.push(tensor_f64_at(thresholds, r, col));
        r = r + 1;
    };
    return tensor_f64_from_vec(thresholds.shape.rows, 1, data);
}

fn ai_temperature_softmax_f64(logits: &TensorF64, temperature: f64) -> TensorF64 {
    if logits.shape.cols <= 0 {
        print("ai error: logits must have at least one class");
        return tensor_f64_zeros(0, 0);
    };
    if temperature <= 0.0 {
        print("ai error: temperature must be positive");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < logits.shape.rows {
        let mut max_val: f64 = tensor_f64_at(logits, r, 0) / temperature;
        let mut c: i64 = 1;
        while c < logits.shape.cols {
            let scaled: f64 = tensor_f64_at(logits, r, c) / temperature;
            if scaled > max_val { max_val = scaled; };
            c = c + 1;
        };

        let mut denom: f64 = 0.0;
        c = 0;
        while c < logits.shape.cols {
            denom = denom + math_exp_f64((tensor_f64_at(logits, r, c) / temperature) - max_val);
            c = c + 1;
        };

        c = 0;
        while c < logits.shape.cols {
            data.push(math_exp_f64((tensor_f64_at(logits, r, c) / temperature) - max_val) / denom);
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(logits.shape.rows, logits.shape.cols, data);
}

fn ai_top_k_f64(logits: &TensorF64, k: i64) -> TopKF64 {
    if k <= 0 {
        print("ai error: top-k must be positive");
        return TopKF64 { values: tensor_f64_zeros(0, 0), indices: tensor_i64_zeros(0, 0) };
    };
    if k > logits.shape.cols {
        print("ai error: top-k cannot exceed class count");
        return TopKF64 { values: tensor_f64_zeros(0, 0), indices: tensor_i64_zeros(0, 0) };
    };

    let mut values: Vec<f64> = Vec::new();
    let mut indices: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < logits.shape.rows {
        let row_start: i64 = vec_len(indices);
        let mut rank: i64 = 0;
        while rank < k {
            let mut best_col: i64 = 0;
            let mut best_val: f64 = 0.0;
            let mut found: i64 = 0;
            let mut c: i64 = 0;
            while c < logits.shape.cols {
                let mut used: i64 = 0;
                let mut s: i64 = row_start;
                while s < vec_len(indices) {
                    if indices[s] == c { used = 1; };
                    s = s + 1;
                };
                if used == 0 {
                    let v: f64 = tensor_f64_at(logits, r, c);
                    if found == 0 || v > best_val {
                        found = 1;
                        best_val = v;
                        best_col = c;
                    };
                };
                c = c + 1;
            };
            values.push(best_val);
            indices.push(best_col);
            rank = rank + 1;
        };
        r = r + 1;
    };
    return TopKF64 {
        values: tensor_f64_from_vec(logits.shape.rows, k, values),
        indices: tensor_i64_from_vec(logits.shape.rows, k, indices)
    };
}

fn ai_top_p_f64(probabilities: &TensorF64, top_p: f64) -> TopPF64 {
    if probabilities.shape.cols <= 0 {
        print("ai error: probabilities must have at least one class");
        return TopPF64 {
            probabilities: tensor_f64_zeros(0, 0),
            indices: tensor_i64_zeros(0, 0),
            counts: tensor_i64_zeros(0, 0)
        };
    };
    if top_p <= 0.0 || top_p > 1.0 {
        print("ai error: top-p must be in (0, 1]");
        return TopPF64 {
            probabilities: tensor_f64_zeros(0, 0),
            indices: tensor_i64_zeros(0, 0),
            counts: tensor_i64_zeros(0, 0)
        };
    };

    let mut filtered: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(probabilities) {
        filtered.push(0.0);
        i = i + 1;
    };

    let mut indices: Vec<i64> = Vec::new();
    let mut counts: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < probabilities.shape.rows {
        let row_start: i64 = vec_len(indices);
        let mut cumulative: f64 = 0.0;
        let mut kept_sum: f64 = 0.0;
        let mut kept_count: i64 = 0;
        let mut done: i64 = 0;
        while kept_count < probabilities.shape.cols && done == 0 {
            let mut best_col: i64 = 0;
            let mut best_val: f64 = 0.0;
            let mut found: i64 = 0;
            let mut c: i64 = 0;
            while c < probabilities.shape.cols {
                let mut used: i64 = 0;
                let mut s: i64 = row_start;
                while s < vec_len(indices) {
                    if indices[s] == c { used = 1; };
                    s = s + 1;
                };
                if used == 0 {
                    let v: f64 = tensor_f64_at(probabilities, r, c);
                    if found == 0 || v > best_val {
                        found = 1;
                        best_val = v;
                        best_col = c;
                    };
                };
                c = c + 1;
            };

            indices.push(best_col);
            cumulative = cumulative + best_val;
            kept_sum = kept_sum + best_val;
            vec_set(filtered, tensor_f64_index(probabilities, r, best_col), best_val);
            kept_count = kept_count + 1;
            if cumulative >= top_p { done = 1; };
        };

        if kept_sum > 0.0 {
            let mut c2: i64 = 0;
            while c2 < probabilities.shape.cols {
                let pos: i64 = tensor_f64_index(probabilities, r, c2);
                if filtered[pos] > 0.0 {
                    vec_set(filtered, pos, filtered[pos] / kept_sum);
                };
                c2 = c2 + 1;
            };
        };

        while vec_len(indices) < row_start + probabilities.shape.cols {
            indices.push(-1);
        };
        counts.push(kept_count);
        r = r + 1;
    };

    return TopPF64 {
        probabilities: tensor_f64_from_vec(probabilities.shape.rows, probabilities.shape.cols, filtered),
        indices: tensor_i64_from_vec(probabilities.shape.rows, probabilities.shape.cols, indices),
        counts: tensor_i64_from_vec(probabilities.shape.rows, 1, counts)
    };
}

fn ai_temperature_top_p_f64(logits: &TensorF64, temperature: f64, top_p: f64) -> TopPF64 {
    let probabilities: TensorF64 = ai_temperature_softmax_f64(logits, temperature);
    return ai_top_p_f64(&probabilities, top_p);
}

fn ai_categorical_sample_i64(probabilities: &TensorF64, thresholds: &TensorF64) -> TensorI64 {
    if probabilities.shape.cols <= 0 {
        print("ai error: probabilities must have at least one class");
        return tensor_i64_zeros(0, 0);
    };
    if thresholds.shape.rows != probabilities.shape.rows || thresholds.shape.cols != 1 {
        print("ai error: thresholds must be shaped rows x 1");
        return tensor_i64_zeros(0, 0);
    };

    let mut samples: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < probabilities.shape.rows {
        let threshold: f64 = tensor_f64_at(thresholds, r, 0);
        let mut cumulative: f64 = 0.0;
        let mut chosen: i64 = -1;
        let mut c: i64 = 0;
        while c < probabilities.shape.cols && chosen < 0 {
            cumulative = cumulative + tensor_f64_at(probabilities, r, c);
            if threshold <= cumulative { chosen = c; };
            c = c + 1;
        };
        if chosen < 0 { chosen = probabilities.shape.cols - 1; };
        samples.push(chosen);
        r = r + 1;
    };
    return tensor_i64_from_vec(probabilities.shape.rows, 1, samples);
}

fn ai_embedding_lm_head_decode_step_f64(embedding: &TensorF64, token_ids: &TensorI64, lm_head_weight: &TensorF64, lm_head_bias: &TensorF64, temperature: f64, k: i64) -> DecodeStepF64 {
    let hidden: TensorF64 = ai_token_embedding_f64(embedding, token_ids);
    let logits: TensorF64 = ai_lm_head_logits_f64(&hidden, lm_head_weight, lm_head_bias);
    let probabilities: TensorF64 = ai_temperature_softmax_f64(&logits, temperature);
    let greedy_tokens: TensorI64 = ai_greedy_next_token_i64(&logits);
    let topk: TopKF64 = ai_top_k_f64(&logits, k);
    return DecodeStepF64 {
        hidden: hidden,
        logits: logits,
        probabilities: probabilities,
        greedy_tokens: greedy_tokens,
        top_values: topk.values,
        top_indices: topk.indices
    };
}

fn ai_embedding_lm_head_sample_step_f64(embedding: &TensorF64, token_ids: &TensorI64, lm_head_weight: &TensorF64, lm_head_bias: &TensorF64, thresholds: &TensorF64, temperature: f64, top_p: f64) -> SampledGenerationStepF64 {
    let last_tokens: TensorI64 = ai_last_token_i64(token_ids);
    let hidden: TensorF64 = ai_token_embedding_f64(embedding, &last_tokens);
    let logits: TensorF64 = ai_lm_head_logits_f64(&hidden, lm_head_weight, lm_head_bias);
    let probabilities: TensorF64 = ai_temperature_softmax_f64(&logits, temperature);
    let nucleus: TopPF64 = ai_top_p_f64(&probabilities, top_p);
    let sampled_tokens: TensorI64 = ai_categorical_sample_i64(&nucleus.probabilities, thresholds);
    let output_token_ids: TensorI64 = ai_append_next_token_i64(token_ids, &sampled_tokens);
    return SampledGenerationStepF64 {
        last_tokens: last_tokens,
        hidden: hidden,
        logits: logits,
        probabilities: probabilities,
        filtered_probabilities: nucleus.probabilities,
        sampled_tokens: sampled_tokens,
        output_token_ids: output_token_ids
    };
}

fn ai_embedding_lm_head_generate_f64(embedding: &TensorF64, token_ids: &TensorI64, lm_head_weight: &TensorF64, lm_head_bias: &TensorF64, thresholds: &TensorF64, steps: i64, temperature: f64, top_p: f64) -> GeneratedTokensI64 {
    if steps < 0 {
        print("ai error: generation steps must be non-negative");
        return GeneratedTokensI64 { token_ids: tensor_i64_zeros(0, 0), sampled_tokens: tensor_i64_zeros(0, 0) };
    };
    if thresholds.shape.rows != token_ids.shape.rows {
        print("ai error: generation thresholds rows must match token rows");
        return GeneratedTokensI64 { token_ids: tensor_i64_zeros(0, 0), sampled_tokens: tensor_i64_zeros(0, 0) };
    };
    if thresholds.shape.cols < steps {
        print("ai error: generation thresholds need one column per step");
        return GeneratedTokensI64 { token_ids: tensor_i64_zeros(0, 0), sampled_tokens: tensor_i64_zeros(0, 0) };
    };

    let mut current: TensorI64 = ai_clone_token_ids_i64(token_ids);
    let mut sampled_history: TensorI64 = tensor_i64_zeros(token_ids.shape.rows, 0);
    let mut step_idx: i64 = 0;
    while step_idx < steps {
        let step_thresholds: TensorF64 = ai_threshold_column_f64(thresholds, step_idx);
        let generated_step: SampledGenerationStepF64 = ai_embedding_lm_head_sample_step_f64(embedding, &current, lm_head_weight, lm_head_bias, &step_thresholds, temperature, top_p);
        sampled_history = ai_append_next_token_i64(&sampled_history, &generated_step.sampled_tokens);
        current = generated_step.output_token_ids;
        step_idx = step_idx + 1;
    };

    return GeneratedTokensI64 {
        token_ids: current,
        sampled_tokens: sampled_history
    };
}

fn ai_attention_score_f64(query: &TensorF64, key: &TensorF64, query_row: i64, key_row: i64, scale: f64) -> f64 {
    let mut acc: f64 = 0.0;
    let mut d: i64 = 0;
    while d < query.shape.cols {
        acc = acc + tensor_f64_at(query, query_row, d) * tensor_f64_at(key, key_row, d);
        d = d + 1;
    };
    return acc * scale;
}

fn ai_attention_head_score_f64(query: &TensorF64, key: &TensorF64, query_row: i64, key_row: i64, head_start: i64, head_dim: i64, scale: f64) -> f64 {
    let mut acc: f64 = 0.0;
    let mut d: i64 = 0;
    while d < head_dim {
        let col: i64 = head_start + d;
        acc = acc + tensor_f64_at(query, query_row, col) * tensor_f64_at(key, key_row, col);
        d = d + 1;
    };
    return acc * scale;
}

fn ai_scaled_dot_product_attention_f64(query: &TensorF64, key: &TensorF64, value: &TensorF64, causal: i64) -> TensorF64 {
    if query.shape.cols != key.shape.cols {
        print("ai error: query/key dimensions must match");
        return tensor_f64_zeros(0, 0);
    };
    if key.shape.rows != value.shape.rows {
        print("ai error: key/value sequence lengths must match");
        return tensor_f64_zeros(0, 0);
    };
    if query.shape.cols <= 0 {
        print("ai error: attention dimension must be positive");
        return tensor_f64_zeros(0, 0);
    };
    if key.shape.rows <= 0 {
        print("ai error: key sequence length must be positive");
        return tensor_f64_zeros(0, 0);
    };

    let scale: f64 = 1.0 / math_sqrt_f64(query.shape.cols as f64);
    let mut out: Vec<f64> = Vec::new();
    let mut qr: i64 = 0;
    while qr < query.shape.rows {
        let mut max_score: f64 = ai_attention_score_f64(query, key, qr, 0, scale);
        let mut kr: i64 = 0;
        while kr < key.shape.rows {
            if causal == 0 || kr <= qr {
                let score: f64 = ai_attention_score_f64(query, key, qr, kr, scale);
                if score > max_score { max_score = score; };
            };
            kr = kr + 1;
        };

        let mut denom: f64 = 0.0;
        kr = 0;
        while kr < key.shape.rows {
            if causal == 0 || kr <= qr {
                denom = denom + math_exp_f64(ai_attention_score_f64(query, key, qr, kr, scale) - max_score);
            };
            kr = kr + 1;
        };

        let mut vc: i64 = 0;
        while vc < value.shape.cols {
            let mut acc: f64 = 0.0;
            kr = 0;
            while kr < key.shape.rows {
                if causal == 0 || kr <= qr {
                    let weight: f64 = math_exp_f64(ai_attention_score_f64(query, key, qr, kr, scale) - max_score) / denom;
                    acc = acc + weight * tensor_f64_at(value, kr, vc);
                };
                kr = kr + 1;
            };
            out.push(acc);
            vc = vc + 1;
        };
        qr = qr + 1;
    };

    return tensor_f64_from_vec(query.shape.rows, value.shape.cols, out);
}

fn ai_kv_cache_attention_f64(query: &TensorF64, cache: &KvCacheF64) -> TensorF64 {
    return ai_scaled_dot_product_attention_f64(query, &cache.keys, &cache.values, 0);
}

fn ai_multi_head_scaled_dot_product_attention_f64(query: &TensorF64, key: &TensorF64, value: &TensorF64, head_count: i64, causal: i64) -> TensorF64 {
    if head_count <= 0 {
        print("ai error: head_count must be positive");
        return tensor_f64_zeros(0, 0);
    };
    if query.shape.cols != key.shape.cols {
        print("ai error: query/key dimensions must match");
        return tensor_f64_zeros(0, 0);
    };
    if query.shape.cols != value.shape.cols {
        print("ai error: query/value dimensions must match for packed heads");
        return tensor_f64_zeros(0, 0);
    };
    if key.shape.rows != value.shape.rows {
        print("ai error: key/value sequence lengths must match");
        return tensor_f64_zeros(0, 0);
    };
    let head_dim: i64 = query.shape.cols / head_count;
    if head_dim <= 0 {
        print("ai error: head dimension must be positive");
        return tensor_f64_zeros(0, 0);
    };
    if head_dim * head_count != query.shape.cols {
        print("ai error: model dimension must divide evenly by head_count");
        return tensor_f64_zeros(0, 0);
    };
    if key.shape.rows <= 0 {
        print("ai error: key sequence length must be positive");
        return tensor_f64_zeros(0, 0);
    };

    let scale: f64 = 1.0 / math_sqrt_f64(head_dim as f64);
    let mut out: Vec<f64> = Vec::new();
    let mut qr: i64 = 0;
    while qr < query.shape.rows {
        let mut h: i64 = 0;
        while h < head_count {
            let head_start: i64 = h * head_dim;
            let mut max_score: f64 = ai_attention_head_score_f64(query, key, qr, 0, head_start, head_dim, scale);
            let mut kr: i64 = 0;
            while kr < key.shape.rows {
                if causal == 0 || kr <= qr {
                    let score: f64 = ai_attention_head_score_f64(query, key, qr, kr, head_start, head_dim, scale);
                    if score > max_score { max_score = score; };
                };
                kr = kr + 1;
            };

            let mut denom: f64 = 0.0;
            kr = 0;
            while kr < key.shape.rows {
                if causal == 0 || kr <= qr {
                    denom = denom + math_exp_f64(ai_attention_head_score_f64(query, key, qr, kr, head_start, head_dim, scale) - max_score);
                };
                kr = kr + 1;
            };

            let mut d: i64 = 0;
            while d < head_dim {
                let value_col: i64 = head_start + d;
                let mut acc: f64 = 0.0;
                kr = 0;
                while kr < key.shape.rows {
                    if causal == 0 || kr <= qr {
                        let weight: f64 = math_exp_f64(ai_attention_head_score_f64(query, key, qr, kr, head_start, head_dim, scale) - max_score) / denom;
                        acc = acc + weight * tensor_f64_at(value, kr, value_col);
                    };
                    kr = kr + 1;
                };
                out.push(acc);
                d = d + 1;
            };
            h = h + 1;
        };
        qr = qr + 1;
    };

    return tensor_f64_from_vec(query.shape.rows, value.shape.cols, out);
}

fn ai_rope_pairs_f64(input: &TensorF64, cos: &TensorF64, sin: &TensorF64) -> TensorF64 {
    let half_cols: i64 = input.shape.cols / 2;
    if half_cols * 2 != input.shape.cols {
        print("ai error: RoPE input cols must be even");
        return tensor_f64_zeros(0, 0);
    };
    if cos.shape.rows != input.shape.rows || sin.shape.rows != input.shape.rows {
        print("ai error: RoPE cos/sin rows must match input rows");
        return tensor_f64_zeros(0, 0);
    };
    if cos.shape.cols != half_cols || sin.shape.cols != half_cols {
        print("ai error: RoPE cos/sin cols must equal input cols / 2");
        return tensor_f64_zeros(0, 0);
    };

    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < input.shape.rows {
        let mut p: i64 = 0;
        while p < half_cols {
            let even_col: i64 = p * 2;
            let odd_col: i64 = even_col + 1;
            let even_v: f64 = tensor_f64_at(input, r, even_col);
            let odd_v: f64 = tensor_f64_at(input, r, odd_col);
            let c: f64 = tensor_f64_at(cos, r, p);
            let s: f64 = tensor_f64_at(sin, r, p);
            out.push(even_v * c - odd_v * s);
            out.push(even_v * s + odd_v * c);
            p = p + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, out);
}

fn ai_swiglu_feed_forward_f64(input: &TensorF64, gate_weight: &TensorF64, gate_bias: &TensorF64, up_weight: &TensorF64, up_bias: &TensorF64, down_weight: &TensorF64, down_bias: &TensorF64) -> TensorF64 {
    let gate: TensorF64 = nn_linear_f64(input, gate_weight, gate_bias);
    let up: TensorF64 = nn_linear_f64(input, up_weight, up_bias);
    let gate_act: TensorF64 = nn_silu_f64(&gate);
    let gated: TensorF64 = tensor_f64_mul(&gate_act, &up);
    return nn_linear_f64(&gated, down_weight, down_bias);
}

fn ai_rmsnorm_swiglu_feed_forward_block_f64(input: &TensorF64, rms_weight: &TensorF64, gate_weight: &TensorF64, gate_bias: &TensorF64, up_weight: &TensorF64, up_bias: &TensorF64, down_weight: &TensorF64, down_bias: &TensorF64, eps: f64) -> TensorF64 {
    let normalized: TensorF64 = nn_rms_norm_f64(input, rms_weight, eps);
    let projected: TensorF64 = ai_swiglu_feed_forward_f64(&normalized, gate_weight, gate_bias, up_weight, up_bias, down_weight, down_bias);
    return tensor_f64_add(input, &projected);
}

fn ai_transformer_self_attention_block_f64(input: &TensorF64, ln_weight: &TensorF64, ln_bias: &TensorF64, q_weight: &TensorF64, q_bias: &TensorF64, k_weight: &TensorF64, k_bias: &TensorF64, v_weight: &TensorF64, v_bias: &TensorF64, out_weight: &TensorF64, out_bias: &TensorF64, eps: f64, causal: i64) -> TensorF64 {
    let normalized: TensorF64 = nn_layer_norm_f64(input, ln_weight, ln_bias, eps);
    let query: TensorF64 = nn_linear_f64(&normalized, q_weight, q_bias);
    let key: TensorF64 = nn_linear_f64(&normalized, k_weight, k_bias);
    let value: TensorF64 = nn_linear_f64(&normalized, v_weight, v_bias);
    let attended: TensorF64 = ai_scaled_dot_product_attention_f64(&query, &key, &value, causal);
    let projected: TensorF64 = nn_linear_f64(&attended, out_weight, out_bias);
    return tensor_f64_add(input, &projected);
}

fn ai_transformer_multi_head_self_attention_block_f64(input: &TensorF64, ln_weight: &TensorF64, ln_bias: &TensorF64, q_weight: &TensorF64, q_bias: &TensorF64, k_weight: &TensorF64, k_bias: &TensorF64, v_weight: &TensorF64, v_bias: &TensorF64, out_weight: &TensorF64, out_bias: &TensorF64, eps: f64, head_count: i64, causal: i64) -> TensorF64 {
    let normalized: TensorF64 = nn_layer_norm_f64(input, ln_weight, ln_bias, eps);
    let query: TensorF64 = nn_linear_f64(&normalized, q_weight, q_bias);
    let key: TensorF64 = nn_linear_f64(&normalized, k_weight, k_bias);
    let value: TensorF64 = nn_linear_f64(&normalized, v_weight, v_bias);
    let attended: TensorF64 = ai_multi_head_scaled_dot_product_attention_f64(&query, &key, &value, head_count, causal);
    let projected: TensorF64 = nn_linear_f64(&attended, out_weight, out_bias);
    return tensor_f64_add(input, &projected);
}

fn ai_transformer_feed_forward_block_f64(input: &TensorF64, ln_weight: &TensorF64, ln_bias: &TensorF64, w1: &TensorF64, b1: &TensorF64, w2: &TensorF64, b2: &TensorF64, eps: f64) -> TensorF64 {
    let normalized: TensorF64 = nn_layer_norm_f64(input, ln_weight, ln_bias, eps);
    let projected: TensorF64 = nn_two_layer_gelu_tanh_f64(&normalized, w1, b1, w2, b2);
    return tensor_f64_add(input, &projected);
}

fn ai_transformer_decoder_layer_f64(input: &TensorF64, attn_ln_weight: &TensorF64, attn_ln_bias: &TensorF64, q_weight: &TensorF64, q_bias: &TensorF64, k_weight: &TensorF64, k_bias: &TensorF64, v_weight: &TensorF64, v_bias: &TensorF64, attn_out_weight: &TensorF64, attn_out_bias: &TensorF64, ff_ln_weight: &TensorF64, ff_ln_bias: &TensorF64, ff_w1: &TensorF64, ff_b1: &TensorF64, ff_w2: &TensorF64, ff_b2: &TensorF64, eps: f64, head_count: i64, causal: i64) -> TensorF64 {
    let after_attn: TensorF64 = ai_transformer_multi_head_self_attention_block_f64(input, attn_ln_weight, attn_ln_bias, q_weight, q_bias, k_weight, k_bias, v_weight, v_bias, attn_out_weight, attn_out_bias, eps, head_count, causal);
    return ai_transformer_feed_forward_block_f64(&after_attn, ff_ln_weight, ff_ln_bias, ff_w1, ff_b1, ff_w2, ff_b2, eps);
}

fn ai_transformer_decoder_layer_with_weights_f64(input: &TensorF64, weights: &TransformerDecoderLayerWeightsF64, eps: f64, head_count: i64, causal: i64) -> TensorF64 {
    return ai_transformer_decoder_layer_f64(
        input,
        &weights.attn_ln_weight,
        &weights.attn_ln_bias,
        &weights.q_weight,
        &weights.q_bias,
        &weights.k_weight,
        &weights.k_bias,
        &weights.v_weight,
        &weights.v_bias,
        &weights.attn_out_weight,
        &weights.attn_out_bias,
        &weights.ff_ln_weight,
        &weights.ff_ln_bias,
        &weights.ff_w1,
        &weights.ff_b1,
        &weights.ff_w2,
        &weights.ff_b2,
        eps,
        head_count,
        causal
    );
}

fn ai_embedding_decoder_lm_head_greedy_step_f64(embedding: &TensorF64, position_embedding: &TensorF64, token_ids: &TensorI64, decoder: &TransformerDecoderLayerWeightsF64, lm_head: &LmHeadWeightsF64, eps: f64, head_count: i64, causal: i64) -> DecoderLmHeadGreedyStepF64 {
    let input_embeddings: TensorF64 = ai_token_position_embedding_f64(embedding, position_embedding, token_ids);
    let hidden: TensorF64 = ai_transformer_decoder_layer_with_weights_f64(&input_embeddings, decoder, eps, head_count, causal);
    let logits: TensorF64 = ai_sequence_lm_head_last_logits_from_weights_f64(&hidden, lm_head);
    let greedy_tokens: TensorI64 = ai_greedy_next_token_i64(&logits);
    let output_token_ids: TensorI64 = ai_append_next_token_i64(token_ids, &greedy_tokens);
    return DecoderLmHeadGreedyStepF64 {
        input_embeddings: input_embeddings,
        hidden: hidden,
        logits: logits,
        greedy_tokens: greedy_tokens,
        output_token_ids: output_token_ids
    };
}

fn ai_embedding_decoder_lm_head_generate_greedy_f64(embedding: &TensorF64, position_embedding: &TensorF64, token_ids: &TensorI64, decoder: &TransformerDecoderLayerWeightsF64, lm_head: &LmHeadWeightsF64, steps: i64, eps: f64, head_count: i64, causal: i64) -> GeneratedTokensI64 {
    if steps < 0 {
        print("ai error: generation steps must be non-negative");
        return GeneratedTokensI64 { token_ids: tensor_i64_zeros(0, 0), sampled_tokens: tensor_i64_zeros(0, 0) };
    };
    if steps > 0 {
        if token_ids.shape.cols + steps - 1 > position_embedding.shape.rows {
            print("ai error: position embedding needs one row for each decoder input position");
            return GeneratedTokensI64 { token_ids: tensor_i64_zeros(0, 0), sampled_tokens: tensor_i64_zeros(0, 0) };
        };
    };

    let mut current: TensorI64 = ai_clone_token_ids_i64(token_ids);
    let mut greedy_history: TensorI64 = tensor_i64_zeros(token_ids.shape.rows, 0);
    let mut step_idx: i64 = 0;
    while step_idx < steps {
        let generated_step: DecoderLmHeadGreedyStepF64 = ai_embedding_decoder_lm_head_greedy_step_f64(embedding, position_embedding, &current, decoder, lm_head, eps, head_count, causal);
        greedy_history = ai_append_next_token_i64(&greedy_history, &generated_step.greedy_tokens);
        current = generated_step.output_token_ids;
        step_idx = step_idx + 1;
    };

    return GeneratedTokensI64 {
        token_ids: current,
        sampled_tokens: greedy_history
    };
}
