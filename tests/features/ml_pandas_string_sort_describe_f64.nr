import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_string_sort_describe_f64",
        "pandas string-key sort_values describe",
        "nuc::data::frame_str_f64_sort_by_key_asc + describe_value",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        5,
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
    let sorted: FrameStrF64 = frame_str_f64_sort_by_key_asc(&frame);
    frame_str_f64_print_key_value("sorted category value:", &sorted);
    let described: DescribeF64 = frame_str_f64_describe_value(&frame);
    describe_f64_print("describe count mean min max:", &described);
    return 0;
}
