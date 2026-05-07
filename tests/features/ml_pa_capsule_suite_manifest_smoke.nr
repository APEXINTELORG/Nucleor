import "stdlib/rods/ml/capsule_facade.nr"

fn main() -> i32 {
    let manifest: CapsuleSuiteManifest = capsule_suite_manifest(
        "nucleor_ml_suite",
        "nuc::capsule::suite_manifest",
        policy_strict(),
        1,
        121,
        12,
        133
    );
    capsule_suite_manifest_print(&manifest);
    capsule_suite_manifest_emit_jsonl("capsule_suite_manifest_smoke", &manifest);
    capsule_emit_status(1);
    return 0;
}
