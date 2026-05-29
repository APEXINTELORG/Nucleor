import "stdlib/rods/ml/rod_registry_facade.nr"

fn main() -> i64 {
    let manifest = rod_registry_manifest(
        "nucleor_ml_suite",
        "nuc_lock_v0",
        "hash_pinned_no_floating_versions",
        "local_plus_stdlib",
        10,
        10,
        2,
        8,
        0,
        12,
        1,
        1,
        1
    );

    rod_registry_manifest_print(&manifest);
    rod_registry_manifest_emit_jsonl(&manifest);
    rod_registry_manifest_emit_status(1);
    if rod_registry_native_available() != 0 { panic("rod_registry_facade falsely advertises a native backend"); };
    return 0;
}
