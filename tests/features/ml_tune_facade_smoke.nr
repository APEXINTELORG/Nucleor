import "stdlib/rods/ml/tune_facade.nr"

fn main() -> i32 {
    let manifest: TuneManifest = tune_manifest(
        "tiny_optuna_ray_tune_fixture",
        8,
        3,
        1,
        2,
        1,
        5,
        20260426,
        0,
        1
    );
    tune_manifest_print(&manifest);
    tune_manifest_emit_jsonl(&manifest);
    tune_manifest_emit_status(1);
    if tune_native_available() != 0 { panic("tune_facade falsely advertises a native backend"); };
    return 0;
}
