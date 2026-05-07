import "stdlib/rods/ml/capsule_facade.nr"

fn main() -> i32 {
    let manifest: CapsuleDeviceManifest = capsule_device_manifest(
        "capsule_device_manifest_smoke",
        "nucleor_ml_suite",
        "nuc::capsule::device_manifest",
        "windows",
        "x86_64",
        "cpu",
        "native_exe",
        policy_strict(),
        1,
        1,
        1
    );
    capsule_device_manifest_print(&manifest);
    capsule_device_manifest_emit_jsonl(&manifest);
    capsule_emit_status(1);
    return 0;
}
