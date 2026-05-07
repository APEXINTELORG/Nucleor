import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_filter_value_eq_i64_f64",
        "pandas boolean filter value == target",
        "nuc::data::frame_i64_f64_filter_value_eq + values_tensor",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        1,
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
    let filtered: FrameI64F64 = frame_i64_f64_filter_value_eq(&frame, 20.0);
    frame_i64_f64_print_key_value("filtered == key value:", &filtered);

    let values: TensorF64 = frame_i64_f64_values_tensor(&filtered);
    tensor_f64_print_flat("filtered == values:", &values);
    print_f64(tensor_f64_sum(&values));
    return 0;
}
