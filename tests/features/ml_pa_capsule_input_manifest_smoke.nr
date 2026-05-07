import "stdlib/rods/ml/capsule_facade.nr"
import "stdlib/rods/ml/data_facade.nr"

fn main() -> i32 {
    let input_path: str = "tests/features/ml_fixtures/multi_sort_describe_i64_f64.csv";
    let frame: FrameI64F64F64 = frame_i64_f64_f64_from_csv_f64(
        input_path,
        "id",
        "x",
        "y",
        1
    );
    let manifest: CapsuleInputManifest = capsule_input_manifest(
        "capsule_input_manifest_smoke",
        "nucleor_ml_suite",
        "nuc::capsule::input_manifest",
        input_path,
        dtype_f64(),
        frame.rows,
        3,
        policy_strict(),
        frame.rows * 3
    );
    capsule_input_manifest_print(&manifest);
    capsule_input_manifest_emit_jsonl(&manifest);
    capsule_emit_status(1);
    return 0;
}
