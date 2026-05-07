// rods/ml/boost_facade — Gradient boosting (XGBoost / LightGBM / CatBoost) parity rods
//
import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/math_facade.nr"

// boost_facade.nr - XGBoost/LightGBM/CatBoost-style tree ensemble inference.
//
// The first supported shape is a deterministic binary stump ensemble. It is a
// small but real bridge for migrated Python notebooks that already have fitted
// tree parameters and need native, auditable scoring.

#[repr(C)]
struct BoostStumpEnsembleF64 {
    feature_indices: Vec<i64>,
    thresholds: Vec<f64>,
    left_values: Vec<f64>,
    right_values: Vec<f64>,
    learning_rate: f64,
    base_score: f64
}

#[repr(C)]
struct BoostTreeEnsembleF64 {
    tree_roots: Vec<i64>,
    tree_output_indices: Vec<i64>,
    node_feature_indices: Vec<i64>,
    node_thresholds: Vec<f64>,
    node_left_indices: Vec<i64>,
    node_right_indices: Vec<i64>,
    node_missing_indices: Vec<i64>,
    node_leaf_values: Vec<f64>,
    node_is_leaf: Vec<i64>,
    base_scores: Vec<f64>,
    learning_rate: f64,
    output_count: i64
}

#[repr(C)]
struct BoostMixedTreeEnsembleF64 {
    tree_roots: Vec<i64>,
    tree_output_indices: Vec<i64>,
    node_feature_sources: Vec<i64>,
    node_split_kinds: Vec<i64>,
    node_feature_indices: Vec<i64>,
    node_thresholds: Vec<f64>,
    node_categories: Vec<i64>,
    node_left_indices: Vec<i64>,
    node_right_indices: Vec<i64>,
    node_missing_indices: Vec<i64>,
    node_leaf_values: Vec<f64>,
    node_is_leaf: Vec<i64>,
    base_scores: Vec<f64>,
    learning_rate: f64,
    output_count: i64
}

#[repr(C)]
struct BoostSparseInputF64 {
    row_ptr: Vec<i64>,
    feature_indices: Vec<i64>,
    values: Vec<f64>,
    row_count: i64,
    feature_count: i64
}

fn boost_stump_ensemble_f64(
    feature_indices: Vec<i64>,
    thresholds: Vec<f64>,
    left_values: Vec<f64>,
    right_values: Vec<f64>,
    learning_rate: f64,
    base_score: f64
) -> BoostStumpEnsembleF64 {
    return BoostStumpEnsembleF64 {
        feature_indices: feature_indices,
        thresholds: thresholds,
        left_values: left_values,
        right_values: right_values,
        learning_rate: learning_rate,
        base_score: base_score
    };
}

fn boost_tree_ensemble_f64(
    tree_roots: Vec<i64>,
    tree_output_indices: Vec<i64>,
    node_feature_indices: Vec<i64>,
    node_thresholds: Vec<f64>,
    node_left_indices: Vec<i64>,
    node_right_indices: Vec<i64>,
    node_missing_indices: Vec<i64>,
    node_leaf_values: Vec<f64>,
    node_is_leaf: Vec<i64>,
    base_scores: Vec<f64>,
    learning_rate: f64,
    output_count: i64
) -> BoostTreeEnsembleF64 {
    return BoostTreeEnsembleF64 {
        tree_roots: tree_roots,
        tree_output_indices: tree_output_indices,
        node_feature_indices: node_feature_indices,
        node_thresholds: node_thresholds,
        node_left_indices: node_left_indices,
        node_right_indices: node_right_indices,
        node_missing_indices: node_missing_indices,
        node_leaf_values: node_leaf_values,
        node_is_leaf: node_is_leaf,
        base_scores: base_scores,
        learning_rate: learning_rate,
        output_count: output_count
    };
}

fn boost_mixed_tree_ensemble_f64(
    tree_roots: Vec<i64>,
    tree_output_indices: Vec<i64>,
    node_feature_sources: Vec<i64>,
    node_split_kinds: Vec<i64>,
    node_feature_indices: Vec<i64>,
    node_thresholds: Vec<f64>,
    node_categories: Vec<i64>,
    node_left_indices: Vec<i64>,
    node_right_indices: Vec<i64>,
    node_missing_indices: Vec<i64>,
    node_leaf_values: Vec<f64>,
    node_is_leaf: Vec<i64>,
    base_scores: Vec<f64>,
    learning_rate: f64,
    output_count: i64
) -> BoostMixedTreeEnsembleF64 {
    return BoostMixedTreeEnsembleF64 {
        tree_roots: tree_roots,
        tree_output_indices: tree_output_indices,
        node_feature_sources: node_feature_sources,
        node_split_kinds: node_split_kinds,
        node_feature_indices: node_feature_indices,
        node_thresholds: node_thresholds,
        node_categories: node_categories,
        node_left_indices: node_left_indices,
        node_right_indices: node_right_indices,
        node_missing_indices: node_missing_indices,
        node_leaf_values: node_leaf_values,
        node_is_leaf: node_is_leaf,
        base_scores: base_scores,
        learning_rate: learning_rate,
        output_count: output_count
    };
}

fn boost_sparse_input_f64(
    row_ptr: Vec<i64>,
    feature_indices: Vec<i64>,
    values: Vec<f64>,
    row_count: i64,
    feature_count: i64
) -> BoostSparseInputF64 {
    return BoostSparseInputF64 {
        row_ptr: row_ptr,
        feature_indices: feature_indices,
        values: values,
        row_count: row_count,
        feature_count: feature_count
    };
}

fn boost_tree_count(model: &BoostStumpEnsembleF64) -> i64 {
    return vec_len(model.feature_indices);
}

fn boost_tree_ensemble_tree_count(model: &BoostTreeEnsembleF64) -> i64 {
    return vec_len(model.tree_roots);
}

fn boost_tree_ensemble_node_count(model: &BoostTreeEnsembleF64) -> i64 {
    return vec_len(model.node_is_leaf);
}

fn boost_mixed_tree_ensemble_tree_count(model: &BoostMixedTreeEnsembleF64) -> i64 {
    return vec_len(model.tree_roots);
}

fn boost_mixed_tree_ensemble_node_count(model: &BoostMixedTreeEnsembleF64) -> i64 {
    return vec_len(model.node_is_leaf);
}

fn boost_model_is_valid(model: &BoostStumpEnsembleF64) -> i64 {
    let n: i64 = boost_tree_count(model);
    if vec_len(model.thresholds) != n { return 0; };
    if vec_len(model.left_values) != n { return 0; };
    if vec_len(model.right_values) != n { return 0; };
    return 1;
}

fn boost_tree_model_is_valid(model: &BoostTreeEnsembleF64) -> i64 {
    let tree_count: i64 = boost_tree_ensemble_tree_count(model);
    let node_count: i64 = boost_tree_ensemble_node_count(model);
    if model.output_count <= 0 { return 0; };
    if vec_len(model.tree_output_indices) != tree_count { return 0; };
    if vec_len(model.base_scores) != model.output_count { return 0; };
    if vec_len(model.node_feature_indices) != node_count { return 0; };
    if vec_len(model.node_thresholds) != node_count { return 0; };
    if vec_len(model.node_left_indices) != node_count { return 0; };
    if vec_len(model.node_right_indices) != node_count { return 0; };
    if vec_len(model.node_missing_indices) != node_count { return 0; };
    if vec_len(model.node_leaf_values) != node_count { return 0; };
    return 1;
}

fn boost_mixed_tree_model_is_valid(model: &BoostMixedTreeEnsembleF64) -> i64 {
    let tree_count: i64 = boost_mixed_tree_ensemble_tree_count(model);
    let node_count: i64 = boost_mixed_tree_ensemble_node_count(model);
    if model.output_count <= 0 { return 0; };
    if vec_len(model.tree_output_indices) != tree_count { return 0; };
    if vec_len(model.base_scores) != model.output_count { return 0; };
    if vec_len(model.node_feature_sources) != node_count { return 0; };
    if vec_len(model.node_split_kinds) != node_count { return 0; };
    if vec_len(model.node_feature_indices) != node_count { return 0; };
    if vec_len(model.node_thresholds) != node_count { return 0; };
    if vec_len(model.node_categories) != node_count { return 0; };
    if vec_len(model.node_left_indices) != node_count { return 0; };
    if vec_len(model.node_right_indices) != node_count { return 0; };
    if vec_len(model.node_missing_indices) != node_count { return 0; };
    if vec_len(model.node_leaf_values) != node_count { return 0; };
    return 1;
}

fn boost_sparse_input_is_valid(x: &BoostSparseInputF64) -> i64 {
    if x.row_count < 0 { return 0; };
    if x.feature_count < 0 { return 0; };
    if vec_len(x.row_ptr) != x.row_count + 1 { return 0; };
    if vec_len(x.feature_indices) != vec_len(x.values) { return 0; };
    if x.row_count == 0 {
        if vec_len(x.row_ptr) != 1 { return 0; };
    };
    let mut r: i64 = 0;
    while r < x.row_count {
        let start: i64 = x.row_ptr[r];
        let end: i64 = x.row_ptr[r + 1];
        if start < 0 { return 0; };
        if end < start { return 0; };
        if end > vec_len(x.feature_indices) { return 0; };
        r = r + 1;
    };
    return 1;
}

fn boost_sparse_input_find_offset(x: &BoostSparseInputF64, row: i64, feature: i64) -> i64 {
    if row < 0 || row >= x.row_count { return -1; };
    if feature < 0 || feature >= x.feature_count { return -1; };
    let start: i64 = x.row_ptr[row];
    let end: i64 = x.row_ptr[row + 1];
    let mut i: i64 = start;
    while i < end {
        if x.feature_indices[i] == feature {
            return i;
        };
        i = i + 1;
    };
    return -1;
}

fn boost_sparse_input_has_feature(x: &BoostSparseInputF64, row: i64, feature: i64) -> i64 {
    if boost_sparse_input_find_offset(x, row, feature) >= 0 {
        return 1;
    };
    return 0;
}

fn boost_sparse_input_value_f64(x: &BoostSparseInputF64, row: i64, feature: i64) -> f64 {
    let offset: i64 = boost_sparse_input_find_offset(x, row, feature);
    if offset < 0 {
        return 0.0;
    };
    return x.values[offset];
}

fn boost_sigmoid_f64(x: f64) -> f64 {
    return 1.0 / (1.0 + math_exp_f64(0.0 - x));
}

fn boost_stump_ensemble_predict_margin_f64(model: &BoostStumpEnsembleF64, x: &TensorF64) -> TensorF64 {
    if boost_model_is_valid(model) == 0 {
        print("boost error: stump ensemble vector lengths must match");
        return tensor_f64_zeros(0, 0);
    };

    let tree_count: i64 = boost_tree_count(model);
    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut margin: f64 = model.base_score;
        let mut t: i64 = 0;
        while t < tree_count {
            let feature: i64 = model.feature_indices[t];
            if feature < 0 || feature >= x.shape.cols {
                print("boost error: feature index out of input range");
                return tensor_f64_zeros(0, 0);
            };
            let value: f64 = tensor_f64_at(x, r, feature);
            if value <= model.thresholds[t] {
                margin = margin + model.learning_rate * model.left_values[t];
            } else {
                margin = margin + model.learning_rate * model.right_values[t];
            };
            t = t + 1;
        };
        out.push(margin);
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, 1, out);
}

fn boost_stump_ensemble_predict_proba_f64(model: &BoostStumpEnsembleF64, x: &TensorF64) -> TensorF64 {
    let margins: TensorF64 = boost_stump_ensemble_predict_margin_f64(model, x);
    let mut out: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&margins) {
        out.push(boost_sigmoid_f64(margins.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(margins.shape.rows, margins.shape.cols, out);
}

fn boost_stump_ensemble_predict_contrib_f64(model: &BoostStumpEnsembleF64, x: &TensorF64, left_weights: Vec<f64>, feature_count: i64) -> TensorF64 {
    if boost_model_is_valid(model) == 0 {
        print("boost error: stump ensemble vector lengths must match");
        return tensor_f64_zeros(0, 0);
    };
    if feature_count <= 0 {
        print("boost error: contribution feature count must be positive");
        return tensor_f64_zeros(0, 0);
    };

    let tree_count: i64 = boost_tree_count(model);
    if vec_len(left_weights) != tree_count {
        print("boost error: contribution branch-prior vector length must match tree count");
        return tensor_f64_zeros(0, 0);
    };

    let out_cols: i64 = feature_count + 1;
    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let row_start: i64 = r * out_cols;
        let mut c: i64 = 0;
        while c < feature_count {
            out.push(0.0);
            c = c + 1;
        };
        out.push(model.base_score);

        let mut t: i64 = 0;
        while t < tree_count {
            let feature: i64 = model.feature_indices[t];
            if feature < 0 || feature >= x.shape.cols || feature >= feature_count {
                print("boost error: contribution feature index out of input range");
                return tensor_f64_zeros(0, 0);
            };

            let left_weight: f64 = left_weights[t];
            let expected_leaf: f64 = left_weight * model.left_values[t] + (1.0 - left_weight) * model.right_values[t];
            let value: f64 = tensor_f64_at(x, r, feature);
            let mut selected_leaf: f64 = model.right_values[t];
            if value <= model.thresholds[t] {
                selected_leaf = model.left_values[t];
            };

            let bias_index: i64 = row_start + feature_count;
            let contrib_index: i64 = row_start + feature;
            vec_set(out, bias_index, out[bias_index] + model.learning_rate * expected_leaf);
            vec_set(out, contrib_index, out[contrib_index] + model.learning_rate * (selected_leaf - expected_leaf));
            t = t + 1;
        };
        r = r + 1;
    };

    return tensor_f64_from_vec(x.shape.rows, out_cols, out);
}

fn boost_stump_ensemble_sum_contrib_f64(contribs: &TensorF64) -> TensorF64 {
    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < contribs.shape.rows {
        let mut sum: f64 = 0.0;
        let mut c: i64 = 0;
        while c < contribs.shape.cols {
            sum = sum + tensor_f64_at(contribs, r, c);
            c = c + 1;
        };
        out.push(sum);
        r = r + 1;
    };
    return tensor_f64_from_vec(contribs.shape.rows, 1, out);
}

fn boost_stump_ensemble_predict_label_i64(model: &BoostStumpEnsembleF64, x: &TensorF64, threshold: f64) -> TensorI64 {
    let probabilities: TensorF64 = boost_stump_ensemble_predict_proba_f64(model, x);
    let mut out: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&probabilities) {
        if probabilities.data[i] >= threshold {
            out.push(1);
        } else {
            out.push(0);
        };
        i = i + 1;
    };
    return tensor_i64_from_vec(probabilities.shape.rows, probabilities.shape.cols, out);
}

fn boost_tree_ensemble_traverse_leaf_f64(model: &BoostTreeEnsembleF64, x: &TensorF64, missing_mask: &TensorI64, row: i64, root: i64) -> f64 {
    let node_count: i64 = boost_tree_ensemble_node_count(model);
    if root < 0 || root >= node_count {
        print("boost error: tree root out of node range");
        return 0.0;
    };

    let mut node: i64 = root;
    let mut guard: i64 = 0;
    while guard <= node_count {
        if model.node_is_leaf[node] != 0 {
            return model.node_leaf_values[node];
        };

        let feature: i64 = model.node_feature_indices[node];
        if feature < 0 || feature >= x.shape.cols {
            print("boost error: split feature out of input range");
            return 0.0;
        };

        if tensor_i64_at(missing_mask, row, feature) != 0 {
            node = model.node_missing_indices[node];
        } else {
            let value: f64 = tensor_f64_at(x, row, feature);
            if value <= model.node_thresholds[node] {
                node = model.node_left_indices[node];
            } else {
                node = model.node_right_indices[node];
            };
        };

        if node < 0 || node >= node_count {
            print("boost error: child node out of range");
            return 0.0;
        };
        guard = guard + 1;
    };

    print("boost error: tree traversal exceeded node guard");
    return 0.0;
}

fn boost_tree_ensemble_traverse_leaf_index_i64(model: &BoostTreeEnsembleF64, x: &TensorF64, missing_mask: &TensorI64, row: i64, root: i64) -> i64 {
    let node_count: i64 = boost_tree_ensemble_node_count(model);
    if root < 0 || root >= node_count {
        print("boost error: tree root out of node range");
        return -1;
    };

    let mut node: i64 = root;
    let mut guard: i64 = 0;
    while guard <= node_count {
        if model.node_is_leaf[node] != 0 {
            return node;
        };

        let feature: i64 = model.node_feature_indices[node];
        if feature < 0 || feature >= x.shape.cols {
            print("boost error: split feature out of input range");
            return -1;
        };

        if tensor_i64_at(missing_mask, row, feature) != 0 {
            node = model.node_missing_indices[node];
        } else {
            let value: f64 = tensor_f64_at(x, row, feature);
            if value <= model.node_thresholds[node] {
                node = model.node_left_indices[node];
            } else {
                node = model.node_right_indices[node];
            };
        };

        if node < 0 || node >= node_count {
            print("boost error: child node out of range");
            return -1;
        };
        guard = guard + 1;
    };

    print("boost error: tree traversal exceeded node guard");
    return -1;
}

fn boost_tree_ensemble_traverse_leaf_sparse_f64(model: &BoostTreeEnsembleF64, x: &BoostSparseInputF64, row: i64, root: i64) -> f64 {
    let node_count: i64 = boost_tree_ensemble_node_count(model);
    if root < 0 || root >= node_count {
        print("boost error: sparse tree root out of node range");
        return 0.0;
    };

    let mut node: i64 = root;
    let mut guard: i64 = 0;
    while guard <= node_count {
        if model.node_is_leaf[node] != 0 {
            return model.node_leaf_values[node];
        };

        let feature: i64 = model.node_feature_indices[node];
        if feature < 0 || feature >= x.feature_count {
            print("boost error: sparse split feature out of input range");
            return 0.0;
        };

        if boost_sparse_input_has_feature(x, row, feature) == 0 {
            node = model.node_missing_indices[node];
        } else {
            let value: f64 = boost_sparse_input_value_f64(x, row, feature);
            if value <= model.node_thresholds[node] {
                node = model.node_left_indices[node];
            } else {
                node = model.node_right_indices[node];
            };
        };

        if node < 0 || node >= node_count {
            print("boost error: sparse child node out of range");
            return 0.0;
        };
        guard = guard + 1;
    };

    print("boost error: sparse tree traversal exceeded node guard");
    return 0.0;
}

fn boost_tree_ensemble_traverse_leaf_index_sparse_i64(model: &BoostTreeEnsembleF64, x: &BoostSparseInputF64, row: i64, root: i64) -> i64 {
    let node_count: i64 = boost_tree_ensemble_node_count(model);
    if root < 0 || root >= node_count {
        print("boost error: sparse tree root out of node range");
        return -1;
    };

    let mut node: i64 = root;
    let mut guard: i64 = 0;
    while guard <= node_count {
        if model.node_is_leaf[node] != 0 {
            return node;
        };

        let feature: i64 = model.node_feature_indices[node];
        if feature < 0 || feature >= x.feature_count {
            print("boost error: sparse split feature out of input range");
            return -1;
        };

        if boost_sparse_input_has_feature(x, row, feature) == 0 {
            node = model.node_missing_indices[node];
        } else {
            let value: f64 = boost_sparse_input_value_f64(x, row, feature);
            if value <= model.node_thresholds[node] {
                node = model.node_left_indices[node];
            } else {
                node = model.node_right_indices[node];
            };
        };

        if node < 0 || node >= node_count {
            print("boost error: sparse child node out of range");
            return -1;
        };
        guard = guard + 1;
    };

    print("boost error: sparse tree traversal exceeded node guard");
    return -1;
}

fn boost_tree_ensemble_predict_margin_f64(model: &BoostTreeEnsembleF64, x: &TensorF64, missing_mask: &TensorI64) -> TensorF64 {
    if boost_tree_model_is_valid(model) == 0 {
        print("boost error: tree ensemble vector lengths must match");
        return tensor_f64_zeros(0, 0);
    };
    if x.shape.rows != missing_mask.shape.rows || x.shape.cols != missing_mask.shape.cols {
        print("boost error: missing mask shape must equal input shape");
        return tensor_f64_zeros(0, 0);
    };

    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut o: i64 = 0;
        while o < model.output_count {
            out.push(model.base_scores[o]);
            o = o + 1;
        };
        r = r + 1;
    };

    let tree_count: i64 = boost_tree_ensemble_tree_count(model);
    r = 0;
    while r < x.shape.rows {
        let mut t: i64 = 0;
        while t < tree_count {
            let output_index: i64 = model.tree_output_indices[t];
            if output_index < 0 || output_index >= model.output_count {
                print("boost error: tree output index out of range");
                return tensor_f64_zeros(0, 0);
            };
            let leaf_value: f64 = boost_tree_ensemble_traverse_leaf_f64(model, x, missing_mask, r, model.tree_roots[t]);
            let out_index: i64 = r * model.output_count + output_index;
            vec_set(out, out_index, out[out_index] + model.learning_rate * leaf_value);
            t = t + 1;
        };
        r = r + 1;
    };

    return tensor_f64_from_vec(x.shape.rows, model.output_count, out);
}

fn boost_tree_ensemble_predict_margin_sparse_f64(model: &BoostTreeEnsembleF64, x: &BoostSparseInputF64) -> TensorF64 {
    if boost_tree_model_is_valid(model) == 0 {
        print("boost error: sparse tree ensemble vector lengths must match");
        return tensor_f64_zeros(0, 0);
    };
    if boost_sparse_input_is_valid(x) == 0 {
        print("boost error: sparse input row pointers and values must be valid");
        return tensor_f64_zeros(0, 0);
    };

    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.row_count {
        let mut o: i64 = 0;
        while o < model.output_count {
            out.push(model.base_scores[o]);
            o = o + 1;
        };
        r = r + 1;
    };

    let tree_count: i64 = boost_tree_ensemble_tree_count(model);
    r = 0;
    while r < x.row_count {
        let mut t: i64 = 0;
        while t < tree_count {
            let output_index: i64 = model.tree_output_indices[t];
            if output_index < 0 || output_index >= model.output_count {
                print("boost error: sparse tree output index out of range");
                return tensor_f64_zeros(0, 0);
            };
            let leaf_value: f64 = boost_tree_ensemble_traverse_leaf_sparse_f64(model, x, r, model.tree_roots[t]);
            let out_index: i64 = r * model.output_count + output_index;
            vec_set(out, out_index, out[out_index] + model.learning_rate * leaf_value);
            t = t + 1;
        };
        r = r + 1;
    };

    return tensor_f64_from_vec(x.row_count, model.output_count, out);
}

fn boost_tree_ensemble_predict_leaf_indices_i64(model: &BoostTreeEnsembleF64, x: &TensorF64, missing_mask: &TensorI64) -> TensorI64 {
    if boost_tree_model_is_valid(model) == 0 {
        print("boost error: tree ensemble vector lengths must match");
        return tensor_i64_zeros(0, 0);
    };
    if x.shape.rows != missing_mask.shape.rows || x.shape.cols != missing_mask.shape.cols {
        print("boost error: missing mask shape must equal input shape");
        return tensor_i64_zeros(0, 0);
    };

    let tree_count: i64 = boost_tree_ensemble_tree_count(model);
    let mut out: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut t: i64 = 0;
        while t < tree_count {
            out.push(boost_tree_ensemble_traverse_leaf_index_i64(model, x, missing_mask, r, model.tree_roots[t]));
            t = t + 1;
        };
        r = r + 1;
    };

    return tensor_i64_from_vec(x.shape.rows, tree_count, out);
}

fn boost_tree_ensemble_predict_leaf_indices_sparse_i64(model: &BoostTreeEnsembleF64, x: &BoostSparseInputF64) -> TensorI64 {
    if boost_tree_model_is_valid(model) == 0 {
        print("boost error: sparse tree ensemble vector lengths must match");
        return tensor_i64_zeros(0, 0);
    };
    if boost_sparse_input_is_valid(x) == 0 {
        print("boost error: sparse input row pointers and values must be valid");
        return tensor_i64_zeros(0, 0);
    };

    let tree_count: i64 = boost_tree_ensemble_tree_count(model);
    let mut out: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.row_count {
        let mut t: i64 = 0;
        while t < tree_count {
            out.push(boost_tree_ensemble_traverse_leaf_index_sparse_i64(model, x, r, model.tree_roots[t]));
            t = t + 1;
        };
        r = r + 1;
    };

    return tensor_i64_from_vec(x.row_count, tree_count, out);
}

fn boost_tree_ensemble_predict_path_indicator_i64(model: &BoostTreeEnsembleF64, x: &TensorF64, missing_mask: &TensorI64) -> TensorI64 {
    if boost_tree_model_is_valid(model) == 0 {
        print("boost error: tree ensemble vector lengths must match");
        return tensor_i64_zeros(0, 0);
    };
    if x.shape.rows != missing_mask.shape.rows || x.shape.cols != missing_mask.shape.cols {
        print("boost error: missing mask shape must equal input shape");
        return tensor_i64_zeros(0, 0);
    };

    let node_count: i64 = boost_tree_ensemble_node_count(model);
    let tree_count: i64 = boost_tree_ensemble_tree_count(model);
    let mut out: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < x.shape.rows * node_count {
        out.push(0);
        i = i + 1;
    };

    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut t: i64 = 0;
        while t < tree_count {
            let root: i64 = model.tree_roots[t];
            if root < 0 || root >= node_count {
                print("boost error: tree root out of node range");
                return tensor_i64_zeros(0, 0);
            };

            let mut node: i64 = root;
            let mut guard: i64 = 0;
            let mut done: i64 = 0;
            while guard <= node_count && done == 0 {
                vec_set(out, r * node_count + node, 1);
                if model.node_is_leaf[node] != 0 {
                    done = 1;
                } else {
                    let feature: i64 = model.node_feature_indices[node];
                    if feature < 0 || feature >= x.shape.cols {
                        print("boost error: split feature out of input range");
                        return tensor_i64_zeros(0, 0);
                    };

                    if tensor_i64_at(missing_mask, r, feature) != 0 {
                        node = model.node_missing_indices[node];
                    } else {
                        let value: f64 = tensor_f64_at(x, r, feature);
                        if value <= model.node_thresholds[node] {
                            node = model.node_left_indices[node];
                        } else {
                            node = model.node_right_indices[node];
                        };
                    };

                    if node < 0 || node >= node_count {
                        print("boost error: child node out of range");
                        return tensor_i64_zeros(0, 0);
                    };
                };
                guard = guard + 1;
            };

            if done == 0 {
                print("boost error: tree path traversal exceeded node guard");
                return tensor_i64_zeros(0, 0);
            };
            t = t + 1;
        };
        r = r + 1;
    };

    return tensor_i64_from_vec(x.shape.rows, node_count, out);
}

fn boost_tree_ensemble_predict_path_indicator_sparse_i64(model: &BoostTreeEnsembleF64, x: &BoostSparseInputF64) -> TensorI64 {
    if boost_tree_model_is_valid(model) == 0 {
        print("boost error: sparse tree ensemble vector lengths must match");
        return tensor_i64_zeros(0, 0);
    };
    if boost_sparse_input_is_valid(x) == 0 {
        print("boost error: sparse input row pointers and values must be valid");
        return tensor_i64_zeros(0, 0);
    };

    let node_count: i64 = boost_tree_ensemble_node_count(model);
    let tree_count: i64 = boost_tree_ensemble_tree_count(model);
    let mut out: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < x.row_count * node_count {
        out.push(0);
        i = i + 1;
    };

    let mut r: i64 = 0;
    while r < x.row_count {
        let mut t: i64 = 0;
        while t < tree_count {
            let root: i64 = model.tree_roots[t];
            if root < 0 || root >= node_count {
                print("boost error: sparse tree root out of node range");
                return tensor_i64_zeros(0, 0);
            };

            let mut node: i64 = root;
            let mut guard: i64 = 0;
            let mut done: i64 = 0;
            while guard <= node_count && done == 0 {
                vec_set(out, r * node_count + node, 1);
                if model.node_is_leaf[node] != 0 {
                    done = 1;
                } else {
                    let feature: i64 = model.node_feature_indices[node];
                    if feature < 0 || feature >= x.feature_count {
                        print("boost error: sparse split feature out of input range");
                        return tensor_i64_zeros(0, 0);
                    };

                    if boost_sparse_input_has_feature(x, r, feature) == 0 {
                        node = model.node_missing_indices[node];
                    } else {
                        let value: f64 = boost_sparse_input_value_f64(x, r, feature);
                        if value <= model.node_thresholds[node] {
                            node = model.node_left_indices[node];
                        } else {
                            node = model.node_right_indices[node];
                        };
                    };

                    if node < 0 || node >= node_count {
                        print("boost error: sparse child node out of range");
                        return tensor_i64_zeros(0, 0);
                    };
                };
                guard = guard + 1;
            };

            if done == 0 {
                print("boost error: sparse tree path traversal exceeded node guard");
                return tensor_i64_zeros(0, 0);
            };
            t = t + 1;
        };
        r = r + 1;
    };

    return tensor_i64_from_vec(x.row_count, node_count, out);
}

fn boost_tree_ensemble_predict_regression_f64(model: &BoostTreeEnsembleF64, x: &TensorF64, missing_mask: &TensorI64) -> TensorF64 {
    return boost_tree_ensemble_predict_margin_f64(model, x, missing_mask);
}

fn boost_tree_ensemble_predict_regression_sparse_f64(model: &BoostTreeEnsembleF64, x: &BoostSparseInputF64) -> TensorF64 {
    return boost_tree_ensemble_predict_margin_sparse_f64(model, x);
}

fn boost_tree_ensemble_predict_binary_proba_f64(model: &BoostTreeEnsembleF64, x: &TensorF64, missing_mask: &TensorI64) -> TensorF64 {
    let margins: TensorF64 = boost_tree_ensemble_predict_margin_f64(model, x, missing_mask);
    let mut out: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&margins) {
        out.push(boost_sigmoid_f64(margins.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(margins.shape.rows, margins.shape.cols, out);
}

fn boost_tree_ensemble_predict_binary_proba_sparse_f64(model: &BoostTreeEnsembleF64, x: &BoostSparseInputF64) -> TensorF64 {
    let margins: TensorF64 = boost_tree_ensemble_predict_margin_sparse_f64(model, x);
    let mut out: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&margins) {
        out.push(boost_sigmoid_f64(margins.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(margins.shape.rows, margins.shape.cols, out);
}

fn boost_tree_ensemble_predict_binary_label_i64(model: &BoostTreeEnsembleF64, x: &TensorF64, missing_mask: &TensorI64, threshold: f64) -> TensorI64 {
    let probabilities: TensorF64 = boost_tree_ensemble_predict_binary_proba_f64(model, x, missing_mask);
    let mut out: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&probabilities) {
        if probabilities.data[i] >= threshold {
            out.push(1);
        } else {
            out.push(0);
        };
        i = i + 1;
    };
    return tensor_i64_from_vec(probabilities.shape.rows, probabilities.shape.cols, out);
}

fn boost_tree_ensemble_predict_binary_label_sparse_i64(model: &BoostTreeEnsembleF64, x: &BoostSparseInputF64, threshold: f64) -> TensorI64 {
    let probabilities: TensorF64 = boost_tree_ensemble_predict_binary_proba_sparse_f64(model, x);
    let mut out: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&probabilities) {
        if probabilities.data[i] >= threshold {
            out.push(1);
        } else {
            out.push(0);
        };
        i = i + 1;
    };
    return tensor_i64_from_vec(probabilities.shape.rows, probabilities.shape.cols, out);
}

fn boost_mixed_tree_ensemble_traverse_leaf_f64(
    model: &BoostMixedTreeEnsembleF64,
    numeric_x: &TensorF64,
    categorical_x: &TensorI64,
    numeric_missing_mask: &TensorI64,
    categorical_missing_mask: &TensorI64,
    row: i64,
    root: i64
) -> f64 {
    let node_count: i64 = boost_mixed_tree_ensemble_node_count(model);
    if root < 0 || root >= node_count {
        print("boost error: mixed tree root out of node range");
        return 0.0;
    };

    let mut node: i64 = root;
    let mut guard: i64 = 0;
    while guard <= node_count {
        if model.node_is_leaf[node] != 0 {
            return model.node_leaf_values[node];
        };

        let source: i64 = model.node_feature_sources[node];
        let split_kind: i64 = model.node_split_kinds[node];
        let feature: i64 = model.node_feature_indices[node];

        if source == 0 {
            if split_kind != 0 {
                print("boost error: numeric mixed tree node must use numeric threshold split");
                return 0.0;
            };
            if feature < 0 || feature >= numeric_x.shape.cols {
                print("boost error: numeric split feature out of input range");
                return 0.0;
            };
            if tensor_i64_at(numeric_missing_mask, row, feature) != 0 {
                node = model.node_missing_indices[node];
            } else {
                let value: f64 = tensor_f64_at(numeric_x, row, feature);
                if value <= model.node_thresholds[node] {
                    node = model.node_left_indices[node];
                } else {
                    node = model.node_right_indices[node];
                };
            };
        } else {
            if source == 1 {
                if split_kind != 1 {
                    print("boost error: categorical mixed tree node must use category equality split");
                    return 0.0;
                };
                if feature < 0 || feature >= categorical_x.shape.cols {
                    print("boost error: categorical split feature out of input range");
                    return 0.0;
                };
                if tensor_i64_at(categorical_missing_mask, row, feature) != 0 {
                    node = model.node_missing_indices[node];
                } else {
                    let category_value: i64 = tensor_i64_at(categorical_x, row, feature);
                    if category_value == model.node_categories[node] {
                        node = model.node_left_indices[node];
                    } else {
                        node = model.node_right_indices[node];
                    };
                };
            } else {
                print("boost error: mixed tree feature source must be 0 numeric or 1 categorical");
                return 0.0;
            };
        };

        if node < 0 || node >= node_count {
            print("boost error: mixed tree child node out of range");
            return 0.0;
        };
        guard = guard + 1;
    };

    print("boost error: mixed tree traversal exceeded node guard");
    return 0.0;
}

fn boost_mixed_tree_ensemble_predict_margin_f64(
    model: &BoostMixedTreeEnsembleF64,
    numeric_x: &TensorF64,
    categorical_x: &TensorI64,
    numeric_missing_mask: &TensorI64,
    categorical_missing_mask: &TensorI64
) -> TensorF64 {
    if boost_mixed_tree_model_is_valid(model) == 0 {
        print("boost error: mixed tree ensemble vector lengths must match");
        return tensor_f64_zeros(0, 0);
    };
    if numeric_x.shape.rows != categorical_x.shape.rows {
        print("boost error: numeric and categorical row counts must match");
        return tensor_f64_zeros(0, 0);
    };
    if numeric_x.shape.rows != numeric_missing_mask.shape.rows || numeric_x.shape.cols != numeric_missing_mask.shape.cols {
        print("boost error: numeric missing mask shape must equal numeric input shape");
        return tensor_f64_zeros(0, 0);
    };
    if categorical_x.shape.rows != categorical_missing_mask.shape.rows || categorical_x.shape.cols != categorical_missing_mask.shape.cols {
        print("boost error: categorical missing mask shape must equal categorical input shape");
        return tensor_f64_zeros(0, 0);
    };

    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < numeric_x.shape.rows {
        let mut o: i64 = 0;
        while o < model.output_count {
            out.push(model.base_scores[o]);
            o = o + 1;
        };
        r = r + 1;
    };

    let tree_count: i64 = boost_mixed_tree_ensemble_tree_count(model);
    r = 0;
    while r < numeric_x.shape.rows {
        let mut t: i64 = 0;
        while t < tree_count {
            let output_index: i64 = model.tree_output_indices[t];
            if output_index < 0 || output_index >= model.output_count {
                print("boost error: mixed tree output index out of range");
                return tensor_f64_zeros(0, 0);
            };
            let leaf_value: f64 = boost_mixed_tree_ensemble_traverse_leaf_f64(
                model,
                numeric_x,
                categorical_x,
                numeric_missing_mask,
                categorical_missing_mask,
                r,
                model.tree_roots[t]
            );
            let out_index: i64 = r * model.output_count + output_index;
            vec_set(out, out_index, out[out_index] + model.learning_rate * leaf_value);
            t = t + 1;
        };
        r = r + 1;
    };

    return tensor_f64_from_vec(numeric_x.shape.rows, model.output_count, out);
}

fn boost_mixed_tree_ensemble_predict_regression_f64(
    model: &BoostMixedTreeEnsembleF64,
    numeric_x: &TensorF64,
    categorical_x: &TensorI64,
    numeric_missing_mask: &TensorI64,
    categorical_missing_mask: &TensorI64
) -> TensorF64 {
    return boost_mixed_tree_ensemble_predict_margin_f64(model, numeric_x, categorical_x, numeric_missing_mask, categorical_missing_mask);
}

fn boost_mixed_tree_ensemble_predict_binary_proba_f64(
    model: &BoostMixedTreeEnsembleF64,
    numeric_x: &TensorF64,
    categorical_x: &TensorI64,
    numeric_missing_mask: &TensorI64,
    categorical_missing_mask: &TensorI64
) -> TensorF64 {
    let margins: TensorF64 = boost_mixed_tree_ensemble_predict_margin_f64(model, numeric_x, categorical_x, numeric_missing_mask, categorical_missing_mask);
    let mut out: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&margins) {
        out.push(boost_sigmoid_f64(margins.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(margins.shape.rows, margins.shape.cols, out);
}

fn boost_mixed_tree_ensemble_predict_binary_label_i64(
    model: &BoostMixedTreeEnsembleF64,
    numeric_x: &TensorF64,
    categorical_x: &TensorI64,
    numeric_missing_mask: &TensorI64,
    categorical_missing_mask: &TensorI64,
    threshold: f64
) -> TensorI64 {
    let probabilities: TensorF64 = boost_mixed_tree_ensemble_predict_binary_proba_f64(model, numeric_x, categorical_x, numeric_missing_mask, categorical_missing_mask);
    let mut out: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&probabilities) {
        if probabilities.data[i] >= threshold {
            out.push(1);
        } else {
            out.push(0);
        };
        i = i + 1;
    };
    return tensor_i64_from_vec(probabilities.shape.rows, probabilities.shape.cols, out);
}

fn boost_tree_ensemble_predict_softmax_f64(model: &BoostTreeEnsembleF64, x: &TensorF64, missing_mask: &TensorI64) -> TensorF64 {
    let margins: TensorF64 = boost_tree_ensemble_predict_margin_f64(model, x, missing_mask);
    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < margins.shape.rows {
        let mut max_value: f64 = tensor_f64_at(&margins, r, 0);
        let mut c: i64 = 1;
        while c < margins.shape.cols {
            let value: f64 = tensor_f64_at(&margins, r, c);
            if value > max_value { max_value = value; };
            c = c + 1;
        };

        let row_start: i64 = vec_len(out);
        let mut sum: f64 = 0.0;
        c = 0;
        while c < margins.shape.cols {
            let exp_value: f64 = math_exp_f64(tensor_f64_at(&margins, r, c) - max_value);
            out.push(exp_value);
            sum = sum + exp_value;
            c = c + 1;
        };

        c = 0;
        while c < margins.shape.cols {
            vec_set(out, row_start + c, out[row_start + c] / sum);
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(margins.shape.rows, margins.shape.cols, out);
}

fn boost_tree_ensemble_predict_multiclass_label_i64(model: &BoostTreeEnsembleF64, x: &TensorF64, missing_mask: &TensorI64) -> TensorI64 {
    let probabilities: TensorF64 = boost_tree_ensemble_predict_softmax_f64(model, x, missing_mask);
    let mut out: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < probabilities.shape.rows {
        let mut best_index: i64 = 0;
        let mut best_value: f64 = tensor_f64_at(&probabilities, r, 0);
        let mut c: i64 = 1;
        while c < probabilities.shape.cols {
            let value: f64 = tensor_f64_at(&probabilities, r, c);
            if value > best_value {
                best_value = value;
                best_index = c;
            };
            c = c + 1;
        };
        out.push(best_index);
        r = r + 1;
    };
    return tensor_i64_from_vec(probabilities.shape.rows, 1, out);
}
