import "stdlib/rods/ml/capsule_facade.nr"

fn main() -> i32 {
    let manifest: CapsuleVerifierManifest = capsule_verifier_manifest(
        "capsule_verifier_manifest_smoke",
        "nucleor_ml_suite",
        "nuc::capsule::verifier_manifest",
        "python",
        "python tools/run_capsule_parity.py",
        policy_strict(),
        1,
        1,
        11
    );
    capsule_verifier_manifest_print(&manifest);
    capsule_verifier_manifest_emit_jsonl(&manifest);
    capsule_emit_status(1);
    return 0;
}
