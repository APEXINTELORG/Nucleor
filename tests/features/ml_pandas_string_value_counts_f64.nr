import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_string_value_counts_f64",
        "pandas string-key value_counts",
        "nuc::data::frame_str_f64_value_counts_by_key",
        dtype_i64(),
        dtype_default_accumulator(dtype_i64()),
        policy_strict(),
        3,
        1,
        0.000001
    );
    parity_manifest_print(&manifest);

    let frame: FrameStrF64 = frame_str_f64_from_csv_f64(
        "tests/features/ml_fixtures/category_value_f64.csv",
        "category",
        "value",
        1
    );
    let counts: ValueCountsStr = frame_str_f64_value_counts_by_key(&frame);
    value_counts_str_print_key_count("category value_counts:", &counts);
    return 0;
}
