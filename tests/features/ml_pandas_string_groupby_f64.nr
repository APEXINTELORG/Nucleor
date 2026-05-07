import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_string_groupby_f64",
        "pandas read_csv string-key groupby sum mean",
        "nuc::data::FrameStrF64 groupby_sum_mean",
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
    let grouped: GroupedStrF64 = frame_str_f64_groupby_sum_mean(&frame);
    grouped_str_f64_print_key_sum_mean("category sum mean:", &grouped);
    return 0;
}
