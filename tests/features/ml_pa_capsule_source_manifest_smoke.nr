import "stdlib/rods/ml/capsule_facade.nr"

fn main() -> i32 {
    let manifest: CapsuleSourceManifest = capsule_source_manifest(
        "capsule_source_manifest_smoke",
        "nucleor_ml_suite",
        "nuc::capsule::source_manifest",
        "examples/capsule_mvp/capsule_source_manifest_smoke.nr",
        "nucleor",
        "entrypoint",
        policy_strict(),
        1,
        1,
        1
    );
    capsule_source_manifest_print(&manifest);
    capsule_source_manifest_emit_jsonl(&manifest);
    capsule_emit_status(1);
    return 0;
}
