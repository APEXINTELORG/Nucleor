import "stdlib/rods/ml/experiment_facade.nr"

fn main() -> i32 {
    let manifest: ExperimentManifest = experiment_manifest(
        "tiny_ml_suite_project",
        "local_capsule_run_001",
        4,
        5,
        3,
        6,
        2,
        1,
        0,
        1
    );
    experiment_manifest_print(&manifest);
    experiment_manifest_emit_jsonl(&manifest);
    experiment_manifest_emit_status(1);
    if experiment_native_available() != 0 { panic("experiment_facade falsely advertises a native backend"); };
    return 0;
}
