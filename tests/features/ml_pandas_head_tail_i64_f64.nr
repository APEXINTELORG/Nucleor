import "stdlib/rods/ml/data_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "pandas_head_tail_i64_f64",
        "pandas head tail row window",
        "nuc::data::frame_i64_f64_head + frame_i64_f64_tail",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        4,
        2,
        0.000001
    );
    parity_manifest_print(&manifest);

    let frame: FrameI64F64 = frame_i64_f64_from_csv_i64(
        "tests/features/ml_fixtures/group_value_i64.csv",
        "group",
        "value",
        1
    );
    let head_rows: FrameI64F64 = frame_i64_f64_head(&frame, 2);
    let tail_rows: FrameI64F64 = frame_i64_f64_tail(&frame, 2);
    frame_i64_f64_print_key_value("head key value:", &head_rows);
    frame_i64_f64_print_key_value("tail key value:", &tail_rows);
    return 0;
}
