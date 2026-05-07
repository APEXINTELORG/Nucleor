import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_string_filter_project_f64",
        "pandas string-key boolean filter value projection",
        "nuc::data::frame_str_f64_filter_value_ge + values_tensor",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        2,
        0.000001
    );
    parity_manifest_print(&manifest);

    let frame: FrameStrF64 = frame_str_f64_from_csv_f64(
        "tests/features/ml_fixtures/category_value_f64.csv",
        "category",
        "value",
        1
    );
    let filtered: FrameStrF64 = frame_str_f64_filter_value_ge(&frame, 2.0);
    frame_str_f64_print_key_value("filtered category value:", &filtered);

    let values: TensorF64 = frame_str_f64_values_tensor(&filtered);
    tensor_f64_print_flat("projected values:", &values);
    print_f64(tensor_f64_sum(&values));
    return 0;
}
