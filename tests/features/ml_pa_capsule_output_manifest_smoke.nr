import "stdlib/rods/ml/capsule_facade.nr"

fn main() -> i32 {
    let manifest: CapsuleOutputManifest = capsule_output_manifest(
        "capsule_output_manifest_smoke",
        "nucleor_ml_suite",
        "nuc::capsule::output_manifest",
        "examples/python_parity/pandas_cumsum_i64_f64/result.json",
        "parity_result",
        "json",
        dtype_f64(),
        5,
        3,
        policy_strict(),
        15,
        1
    );
    capsule_output_manifest_print(&manifest);
    capsule_output_manifest_emit_jsonl(&manifest);
    capsule_emit_status(1);
    return 0;
}
