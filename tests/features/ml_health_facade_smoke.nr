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
    return 0;
}
