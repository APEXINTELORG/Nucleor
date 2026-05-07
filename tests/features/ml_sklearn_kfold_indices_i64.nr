import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_kfold_indices_i64",
        "scikit-learn KFold n_splits=3 shuffle=False indices",
        "nuc::learn::kfold_indices_i64",
        dtype_i64(),
        dtype_default_accumulator(dtype_i64()),
        policy_strict(),
        3,
        6,
        0.000001
    );
    parity_manifest_print(&manifest);

    let folds: KFoldIndicesI64 = kfold_indices_i64(6, 3);
    tensor_i64_print_flat("kfold train indices:", &folds.train_indices);
    tensor_i64_print_flat("kfold test indices:", &folds.test_indices);
    return 0;
}
