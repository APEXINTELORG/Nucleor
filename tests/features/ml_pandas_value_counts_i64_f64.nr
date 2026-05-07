import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_value_counts_i64_f64",
        "pandas i64-key value_counts",
        "nuc::data::frame_i64_f64_value_counts_by_key",
        dtype_i64(),
        dtype_default_accumulator(dtype_i64()),
        policy_strict(),
        3,
        1,
        0.000001
    );
    parity_manifest_print(&manifest);

    let frame: FrameI64F64 = frame_i64_f64_from_csv_i64(
        "tests/features/ml_fixtures/group_value_i64.csv",
        "group",
        "value",
        1
    );
    let counts: ValueCountsI64 = frame_i64_f64_value_counts_by_key(&frame);
    value_counts_i64_print_key_count("group value_counts:", &counts);
    return 0;
}
