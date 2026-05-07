import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_group_kfold_indices_i64",
        "scikit-learn GroupKFold n_splits=2 indices",
        "nuc::learn::group_kfold_indices_i64",
        dtype_i64(),
        dtype_default_accumulator(dtype_i64()),
        policy_strict(),
        2,
        8,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut gd: Vec<i64> = Vec::new();
    gd.push(0); gd.push(0); gd.push(1); gd.push(1);
    gd.push(2); gd.push(2); gd.push(3); gd.push(3);
    let groups: TensorI64 = tensor_i64_from_vec(8, 1, gd);

    let folds: KFoldIndicesI64 = group_kfold_indices_i64(&groups, 2);
    tensor_i64_print_flat("group kfold train indices:", &folds.train_indices);
    tensor_i64_print_flat("group kfold test indices:", &folds.test_indices);
    return 0;
}
