import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_stratified_kfold_indices_i64",
        "scikit-learn StratifiedKFold n_splits=3 shuffle=False indices",
        "nuc::learn::stratified_kfold_indices_i64",
        dtype_i64(),
        dtype_default_accumulator(dtype_i64()),
        policy_strict(),
        3,
        6,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut yd: Vec<i64> = Vec::new();
    yd.push(0); yd.push(0); yd.push(0); yd.push(1); yd.push(1); yd.push(1);
    let y: TensorI64 = tensor_i64_from_vec(6, 1, yd);

    let mut cd: Vec<i64> = Vec::new();
    cd.push(0); cd.push(1);
    let classes: TensorI64 = tensor_i64_from_vec(2, 1, cd);

    let folds: KFoldIndicesI64 = stratified_kfold_indices_i64(&y, &classes, 3);
    tensor_i64_print_flat("stratified kfold train indices:", &folds.train_indices);
    tensor_i64_print_flat("stratified kfold test indices:", &folds.test_indices);
    return 0;
}
