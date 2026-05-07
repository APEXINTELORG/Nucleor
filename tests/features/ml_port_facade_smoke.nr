import "stdlib/rods/ml/port_facade.nr"

fn main() -> i64 {
    let manifest = port_manifest(
        "python",
        "nucleor",
        "nuc_port_plan_v0",
        "examples/port_mvp/python_migration_sample.py",
        "examples/python_parity/python_port_smoke/port_plan.json",
        "examples/python_parity/python_port_smoke/port_candidate.nr",
        32,
        25,
        7,
        0,
        27,
        5,
        1,
        1,
        0
    );

    port_manifest_print(&manifest);
    port_manifest_emit_jsonl(&manifest);
    port_manifest_emit_status(1);
    return 0;
}
