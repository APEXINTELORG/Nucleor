import "stdlib/rods/ml/ml_health_facade.nr"

fn main() -> i64 {
    let manifest = ml_health_manifest(
        "nucleor_ml_suite",
        "nuc_ml_health_v0",
        "local_ml_suite_preflight",
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        0,
        0
    );

    ml_health_manifest_print(&manifest);
    ml_health_manifest_emit_jsonl(&manifest);
    ml_health_manifest_emit_status(1);
    if ml_health_native_available() != 0 { panic("ml_health_facade falsely advertises a native backend"); };
    return 0;
}
