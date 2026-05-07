import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_kfold_accuracy_score_i64",
        "scikit-learn KFold per-fold accuracy scores",
        "nuc::learn::kfold_accuracy_scores_i64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        3,
        1,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut true_data: Vec<i64> = Vec::new();
    true_data.push(0); true_data.push(1); true_data.push(1);
    true_data.push(0); true_data.push(1); true_data.push(0);
    let y_true: TensorI64 = tensor_i64_from_vec(6, 1, true_data);

    let mut pred_data: Vec<i64> = Vec::new();
    pred_data.push(0); pred_data.push(0); pred_data.push(1);
    pred_data.push(0); pred_data.push(0); pred_data.push(1);
    let y_pred: TensorI64 = tensor_i64_from_vec(6, 1, pred_data);

    let folds: KFoldIndicesI64 = kfold_indices_i64(6, 3);
    let scores: TensorF64 = kfold_accuracy_scores_i64(&y_true, &y_pred, &folds.test_indices);
    tensor_f64_print_flat("kfold accuracy scores:", &scores);
    return 0;
}
