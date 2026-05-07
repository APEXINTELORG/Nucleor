import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_sort_values_asc_i64_f64",
        "pandas sort_values ascending by f64 value",
        "nuc::data::frame_i64_f64_sort_by_value_asc + values_tensor",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        5,
        2,
        0.000001
    );
    parity_manifest_print(&manifest);

    let frame: FrameI64F64 = frame_i64_f64_from_csv_i64(
        "tests/features/ml_fixtures/group_value_i64.csv",
        "group",
        "value",
        1
    );
    let sorted: FrameI64F64 = frame_i64_f64_sort_by_value_asc(&frame);
    frame_i64_f64_print_key_value("sorted asc key value:", &sorted);

    let values: TensorF64 = frame_i64_f64_values_tensor(&sorted);
    tensor_f64_print_flat("sorted asc values:", &values);
    print_f64(tensor_f64_sum(&values));
    return 0;
}
