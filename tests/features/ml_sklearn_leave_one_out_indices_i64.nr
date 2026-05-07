import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_leave_one_out_indices_i64",
        "scikit-learn LeaveOneOut train/test indices",
        "nuc::learn::leave_one_out_indices_i64",
        dtype_i64(),
        dtype_default_accumulator(dtype_i64()),
        policy_strict(),
        4,
        4,
        0.000001
    );
    parity_manifest_print(&manifest);

    let folds: KFoldIndicesI64 = leave_one_out_indices_i64(4);
    tensor_i64_print_flat("leave-one-out train indices:", &folds.train_indices);
    tensor_i64_print_flat("leave-one-out test indices:", &folds.test_indices);
    return 0;
}
