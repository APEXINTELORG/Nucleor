import "stdlib/rods/ml/capsule_facade.nr"

fn main() -> i32 {
    let manifest: CapsuleToolchainManifest = capsule_toolchain_manifest(
        "capsule_toolchain_manifest_smoke",
        "nucleor_ml_suite",
        "nuc::capsule::toolchain_manifest",
        "nucleor",
        "bin/nucleor.exe",
        "native_exe",
        policy_strict(),
        1,
        1,
        1
    );
    capsule_toolchain_manifest_print(&manifest);
    capsule_toolchain_manifest_emit_jsonl(&manifest);
    capsule_emit_status(1);
    return 0;
}
