import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_cumsum_i64_f64",
        "pandas cumsum derived f64 column",
        "nuc::data::frame_i64_f64_assign_cumsum_value + values_tensor",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        5,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let frame: FrameI64F64 = frame_i64_f64_from_csv_i64(
        "tests/features/ml_fixtures/group_value_i64.csv",
        "group",
        "value",
        1
    );
    let assigned: FrameI64F64F64 = frame_i64_f64_assign_cumsum_value(&frame, "value_cumsum");
    frame_i64_f64_f64_print_key_values("cumsum group value value_cumsum:", &assigned);

    let values: TensorF64 = frame_i64_f64_f64_values_tensor(&assigned);
    tensor_f64_print_flat("cumsum values tensor:", &values);
    print_f64(tensor_f64_sum(&values));
    return 0;
}
