import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_multi_column_sort_describe_i64_f64",
        "pandas multi-column sort_values describe",
        "nuc::data::FrameI64F64F64 sort_by_key_asc + describe_value0/value1",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        5,
        23,
        0.000001
    );
    parity_manifest_print(&manifest);

    let frame: FrameI64F64F64 = frame_i64_f64_f64_from_csv_f64(
        "tests/features/ml_fixtures/multi_sort_describe_i64_f64.csv",
        "id",
        "x",
        "y",
        1
    );
    let sorted: FrameI64F64F64 = frame_i64_f64_f64_sort_by_key_asc(&frame);
    frame_i64_f64_f64_print_key_values("sorted id x y:", &sorted);

    let desc_x: DescribeF64 = frame_i64_f64_f64_describe_value0(&frame);
    describe_f64_print("describe x count mean min max:", &desc_x);

    let desc_y: DescribeF64 = frame_i64_f64_f64_describe_value1(&frame);
    describe_f64_print("describe y count mean min max:", &desc_y);
    return 0;
}
