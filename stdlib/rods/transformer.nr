// rods/transformer — Classic transformer building blocks
//
// Scaled dot-product attention, multi-head attention, layer norm,
// position-wise feedforward, sinusoidal positional encoding,
// softmax, cross-entropy. The "classic" set from Vaswani et al.
//
// Modern variants (FlashAttention, GQA, MLA, sliding window) live
// in `attention2.nr`; modern activations / norms live in
// `activation2.nr`. This rod is the textbook surface.
//
// All tensor-shaped arguments are i64 handles to flat-allocated
// buffers; shape integers (`seq_len`, `d_model`, etc.) are passed
// alongside.
//
// See `stdlib/runtime/transformer_rt.c`.
#cfile "../runtime/transformer_rt.c"

extern fn nuc_tf_softmax(vh: i64) -> i64;
extern fn nuc_tf_layer_norm(xh: i64, gamma_h: i64, beta_h: i64) -> i64;
extern fn nuc_tf_attention(Q_h: i64, K_h: i64, V_h: i64, seq_len: i64, d_k: i64) -> i64;
extern fn nuc_tf_multihead(Q_h: i64, K_h: i64, V_h: i64, seq_len: i64, d_model: i64, n_heads: i64) -> i64;
extern fn nuc_tf_attention_split(Q_h: i64, K_h: i64, V_h: i64, seq_q: i64, seq_k: i64, d_k: i64, d_v: i64) -> i64;
extern fn nuc_tf_attention_split_masked(Q_h: i64, K_h: i64, V_h: i64, seq_q: i64, seq_k: i64, d_k: i64, d_v: i64, causal: i64) -> i64;
extern fn nuc_tf_attention_causal(Q_h: i64, K_h: i64, V_h: i64, seq_len: i64, d_k: i64) -> i64;
extern fn nuc_tf_multihead_split(Q_h: i64, K_h: i64, V_h: i64, seq_q: i64, seq_k: i64, d_model: i64, n_heads: i64) -> i64;
extern fn nuc_tf_multihead_split_masked(Q_h: i64, K_h: i64, V_h: i64, seq_q: i64, seq_k: i64, d_model: i64, n_heads: i64, causal: i64) -> i64;
extern fn nuc_tf_encoder_decoder_block(tgt_Q_h: i64, tgt_K_h: i64, tgt_V_h: i64, mem_K_h: i64, mem_V_h: i64, seq_tgt: i64, seq_src: i64, d_model: i64, n_heads: i64) -> i64;
extern fn nuc_tf_feedforward(xh: i64, W1_h: i64, b1_h: i64, W2_h: i64, b2_h: i64, d_in: i64, d_hidden: i64) -> i64;
extern fn nuc_tf_positional_encoding(seq_len: i64, d_model: i64) -> i64;
extern fn nuc_tf_cross_entropy(pred_h: i64, target: i64) -> i64;
extern fn nuc_tf_cross_entropy_grad(pred_h: i64, target: i64) -> i64;

fn tf_softmax(v: i64) -> i64 { return nuc_tf_softmax(v); }
fn tf_layer_norm(x: i64, gamma: i64, beta: i64) -> i64 {
    return nuc_tf_layer_norm(x, gamma, beta);
}
fn tf_attention(Q: i64, K: i64, V: i64, seq_len: i64, d_k: i64) -> i64 {
    return nuc_tf_attention(Q, K, V, seq_len, d_k);
}
fn tf_multihead(Q: i64, K: i64, V: i64, seq_len: i64, d_model: i64, n_heads: i64) -> i64 {
    return nuc_tf_multihead(Q, K, V, seq_len, d_model, n_heads);
}
fn tf_attention_split(Q: i64, K: i64, V: i64, seq_q: i64, seq_k: i64, d_k: i64, d_v: i64) -> i64 {
    return nuc_tf_attention_split(Q, K, V, seq_q, seq_k, d_k, d_v);
}
fn tf_attention_split_masked(Q: i64, K: i64, V: i64, seq_q: i64, seq_k: i64, d_k: i64, d_v: i64, causal: i64) -> i64 {
    return nuc_tf_attention_split_masked(Q, K, V, seq_q, seq_k, d_k, d_v, causal);
}
fn tf_attention_causal(Q: i64, K: i64, V: i64, seq_len: i64, d_k: i64) -> i64 {
    return nuc_tf_attention_causal(Q, K, V, seq_len, d_k);
}
fn tf_multihead_split(Q: i64, K: i64, V: i64, seq_q: i64, seq_k: i64, d_model: i64, n_heads: i64) -> i64 {
    return nuc_tf_multihead_split(Q, K, V, seq_q, seq_k, d_model, n_heads);
}
fn tf_multihead_split_masked(Q: i64, K: i64, V: i64, seq_q: i64, seq_k: i64, d_model: i64, n_heads: i64, causal: i64) -> i64 {
    return nuc_tf_multihead_split_masked(Q, K, V, seq_q, seq_k, d_model, n_heads, causal);
}
fn tf_encoder_decoder_block(tgt_Q: i64, tgt_K: i64, tgt_V: i64, mem_K: i64, mem_V: i64, seq_tgt: i64, seq_src: i64, d_model: i64, n_heads: i64) -> i64 {
    return nuc_tf_encoder_decoder_block(tgt_Q, tgt_K, tgt_V, mem_K, mem_V, seq_tgt, seq_src, d_model, n_heads);
}
fn tf_feedforward(x: i64, W1: i64, b1: i64, W2: i64, b2: i64, d_in: i64, d_hidden: i64) -> i64 {
    return nuc_tf_feedforward(x, W1, b1, W2, b2, d_in, d_hidden);
}
fn tf_positional_encoding(seq_len: i64, d_model: i64) -> i64 {
    return nuc_tf_positional_encoding(seq_len, d_model);
}
fn tf_cross_entropy(pred: i64, target: i64) -> i64 {
    return nuc_tf_cross_entropy(pred, target);
}
fn tf_cross_entropy_grad(pred: i64, target: i64) -> i64 {
    return nuc_tf_cross_entropy_grad(pred, target);
}
