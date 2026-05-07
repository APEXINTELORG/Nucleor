import "stdlib/rods/ml/boost_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "xgboost_tree_leaf_indices_f64",
        "XGBoost LightGBM pred_leaf style dense and sparse tree diagnostics",
        "nuc::boost::tree_ensemble_predict_leaf_indices",
        dtype_i64(),
        dtype_default_accumulator(dtype_i64()),
        policy_strict(),
        4,
        2,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(0.2); xd.push(0.2); xd.push(-1.0);
    xd.push(0.2); xd.push(0.8); xd.push(1.5);
    xd.push(1.4); xd.push(0.3); xd.push(2.0);
    xd.push(2.5); xd.push(0.1); xd.push(99.0);
    let x: TensorF64 = tensor_f64_from_vec(4, 3, xd);

    let mut md: Vec<i64> = Vec::new();
    md.push(0); md.push(0); md.push(0);
    md.push(0); md.push(0); md.push(0);
    md.push(0); md.push(0); md.push(0);
    md.push(0); md.push(0); md.push(1);
    let missing_mask: TensorI64 = tensor_i64_from_vec(4, 3, md);

    let mut row_ptr: Vec<i64> = Vec::new();
    row_ptr.push(0); row_ptr.push(3); row_ptr.push(6); row_ptr.push(9); row_ptr.push(11);

    let mut sparse_features: Vec<i64> = Vec::new();
    sparse_features.push(0); sparse_features.push(1); sparse_features.push(2);
    sparse_features.push(0); sparse_features.push(1); sparse_features.push(2);
    sparse_features.push(0); sparse_features.push(1); sparse_features.push(2);
    sparse_features.push(0); sparse_features.push(1);

    let mut sparse_values: Vec<f64> = Vec::new();
    sparse_values.push(0.2); sparse_values.push(0.2); sparse_values.push(-1.0);
    sparse_values.push(0.2); sparse_values.push(0.8); sparse_values.push(1.5);
    sparse_values.push(1.4); sparse_values.push(0.3); sparse_values.push(2.0);
    sparse_values.push(2.5); sparse_values.push(0.1);

    let sparse_x: BoostSparseInputF64 = boost_sparse_input_f64(row_ptr, sparse_features, sparse_values, 4, 3);

    let mut roots: Vec<i64> = Vec::new();
    roots.push(0); roots.push(5);

    let mut outputs: Vec<i64> = Vec::new();
    outputs.push(0); outputs.push(0);

    let mut features: Vec<i64> = Vec::new();
    features.push(0); features.push(1); features.push(-1); features.push(-1); features.push(-1);
    features.push(2); features.push(-1); features.push(0); features.push(-1); features.push(-1);

    let mut thresholds: Vec<f64> = Vec::new();
    thresholds.push(1.0); thresholds.push(0.5); thresholds.push(0.0); thresholds.push(0.0); thresholds.push(0.0);
    thresholds.push(0.0); thresholds.push(0.0); thresholds.push(2.0); thresholds.push(0.0); thresholds.push(0.0);

    let mut left_indices: Vec<i64> = Vec::new();
    left_indices.push(1); left_indices.push(3); left_indices.push(-1); left_indices.push(-1); left_indices.push(-1);
    left_indices.push(6); left_indices.push(-1); left_indices.push(8); left_indices.push(-1); left_indices.push(-1);

    let mut right_indices: Vec<i64> = Vec::new();
    right_indices.push(2); right_indices.push(4); right_indices.push(-1); right_indices.push(-1); right_indices.push(-1);
    right_indices.push(7); right_indices.push(-1); right_indices.push(9); right_indices.push(-1); right_indices.push(-1);

    let mut missing_indices: Vec<i64> = Vec::new();
    missing_indices.push(2); missing_indices.push(4); missing_indices.push(-1); missing_indices.push(-1); missing_indices.push(-1);
    missing_indices.push(6); missing_indices.push(-1); missing_indices.push(8); missing_indices.push(-1); missing_indices.push(-1);

    let mut leaf_values: Vec<f64> = Vec::new();
    leaf_values.push(0.0); leaf_values.push(0.0); leaf_values.push(-0.25); leaf_values.push(0.35); leaf_values.push(-0.1);
    leaf_values.push(0.0); leaf_values.push(0.2); leaf_values.push(0.0); leaf_values.push(-0.05); leaf_values.push(0.4);

    let mut is_leaf: Vec<i64> = Vec::new();
    is_leaf.push(0); is_leaf.push(0); is_leaf.push(1); is_leaf.push(1); is_leaf.push(1);
    is_leaf.push(0); is_leaf.push(1); is_leaf.push(0); is_leaf.push(1); is_leaf.push(1);

    let mut base_scores: Vec<f64> = Vec::new();
    base_scores.push(0.15);

    let model: BoostTreeEnsembleF64 = boost_tree_ensemble_f64(
        roots,
        outputs,
        features,
        thresholds,
        left_indices,
        right_indices,
        missing_indices,
        leaf_values,
        is_leaf,
        base_scores,
        0.7,
        1
    );

    let dense_leaf_indices: TensorI64 = boost_tree_ensemble_predict_leaf_indices_i64(&model, &x, &missing_mask);
    tensor_i64_print_flat("dense leaf indices:", &dense_leaf_indices);

    let sparse_leaf_indices: TensorI64 = boost_tree_ensemble_predict_leaf_indices_sparse_i64(&model, &sparse_x);
    tensor_i64_print_flat("sparse leaf indices:", &sparse_leaf_indices);
    return 0;
}
