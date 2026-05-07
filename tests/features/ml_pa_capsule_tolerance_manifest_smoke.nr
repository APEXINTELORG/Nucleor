import "stdlib/rods/ml/capsule_facade.nr"

fn main() -> i32 {
    let manifest: CapsuleToleranceManifest = capsule_tolerance_manifest(
        "capsule_tolerance_manifest_smoke",
        "nucleor_ml_suite",
        "nuc::capsule::tolerance_manifest",
        "max_abs_error",
        dtype_f64(),
        2,
        3,
        policy_strict(),
        0.000001,
        0.0,
        2
    );
    capsule_tolerance_manifest_print(&manifest);
    capsule_tolerance_manifest_emit_jsonl(&manifest);
    capsule_emit_status(1);
    return 0;
}
