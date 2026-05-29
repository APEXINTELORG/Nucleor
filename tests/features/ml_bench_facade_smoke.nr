import "stdlib/rods/ml/bench_facade.nr"

fn main() -> i64 {
    let manifest = bench_manifest(
        "nucleor_ml_suite",
        "nuc_bench_v0",
        "perf_counter_wall_plus_process_tree_working_set",
        "local_measurement_no_speed_claim",
        3,
        5,
        1,
        1,
        1,
        1,
        0,
        0
    );

    bench_manifest_print(&manifest);
    bench_manifest_emit_jsonl(&manifest);
    bench_manifest_emit_status(1);
    if bench_native_available() != 0 { panic("bench_facade falsely advertises a native backend"); };
    return 0;
}
