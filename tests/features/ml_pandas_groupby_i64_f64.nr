import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_groupby_i64_f64",
        "pandas.read_csv groupby sum mean",
        "nuc::data::frame_i64_f64_groupby_sum_mean",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        3,
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
    let grouped: GroupedI64F64 = frame_i64_f64_groupby_sum_mean(&frame);
    grouped_i64_f64_print_key_sum_mean("group key sum mean:", &grouped);
    return 0;
}
