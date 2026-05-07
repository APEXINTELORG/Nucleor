import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_groupby_count_min_max_i64_f64",
        "pandas read_csv groupby count min max",
        "nuc::data::frame_i64_f64_groupby_count_min_max",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        3,
        4,
        0.000001
    );
    parity_manifest_print(&manifest);

    let frame: FrameI64F64 = frame_i64_f64_from_csv_i64(
        "tests/features/ml_fixtures/group_value_i64.csv",
        "group",
        "value",
        1
    );
    let grouped: GroupedStatsI64F64 = frame_i64_f64_groupby_count_min_max(&frame);
    grouped_stats_i64_f64_print_key_count_min_max("group key count min max:", &grouped);
    return 0;
}
