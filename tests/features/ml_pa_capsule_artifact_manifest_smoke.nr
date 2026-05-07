import "stdlib/rods/ml/capsule_facade.nr"

fn main() -> i32 {
    let manifest: CapsuleArtifactManifest = capsule_artifact_manifest(
        "capsule_artifact_manifest_smoke",
        "nucleor_ml_suite",
        "nuc::capsule::artifact_manifest",
        "examples/python_parity/capsule_manifest_smoke/result.json",
        "parity_result",
        "json",
        policy_strict(),
        1,
        1,
        1
    );
    capsule_artifact_manifest_print(&manifest);
    capsule_artifact_manifest_emit_jsonl(&manifest);
    capsule_emit_status(1);
    return 0;
}
