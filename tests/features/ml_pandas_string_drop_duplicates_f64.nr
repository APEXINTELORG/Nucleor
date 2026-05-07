import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_string_drop_duplicates_f64",
        "pandas string-key drop_duplicates keep first",
        "nuc::data::frame_str_f64_drop_duplicates_by_key_keep_first",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        3,
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
    let unique: FrameStrF64 = frame_str_f64_drop_duplicates_by_key_keep_first(&frame);
    frame_str_f64_print_key_value("deduplicated category value:", &unique);
    return 0;
}
