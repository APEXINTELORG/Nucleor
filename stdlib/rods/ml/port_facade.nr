// rods/ml/port_facade — nuc port migration planner contract (scaffold path, blocker count, capsule attachability)
//
import "stdlib/rods/jsonl.nr"

// port_facade.nr - Python-to-Nucleor migration command manifest.
//
// The port surface is intentionally planner-first. It records what the runtime
// can inspect, map, scaffold, and attach to capsules without pretending full
// automatic Python translation is solved.

#[repr(C)]
struct PortManifest {
    source_language: str,
    target_language: str,
    planner_schema: str,
    source_path: str,
    plan_path: str,
    scaffold_path: str,
    finding_count: i64,
    covered_count: i64,
    partial_count: i64,
    blocker_count: i64,
    target_count: i64,
    suggested_import_count: i64,
    scaffold_emitted: i64,
    capsule_attachable: i64,
    automatic_rewrite_enabled: i64
}

fn port_manifest(
    source_language: str,
    target_language: str,
    planner_schema: str,
    source_path: str,
    plan_path: str,
    scaffold_path: str,
    finding_count: i64,
    covered_count: i64,
    partial_count: i64,
    blocker_count: i64,
    target_count: i64,
    suggested_import_count: i64,
    scaffold_emitted: i64,
    capsule_attachable: i64,
    automatic_rewrite_enabled: i64
) -> PortManifest {
    return PortManifest {
        source_language: source_language,
        target_language: target_language,
        planner_schema: planner_schema,
        source_path: source_path,
        plan_path: plan_path,
        scaffold_path: scaffold_path,
        finding_count: finding_count,
        covered_count: covered_count,
        partial_count: partial_count,
        blocker_count: blocker_count,
        target_count: target_count,
        suggested_import_count: suggested_import_count,
        scaffold_emitted: scaffold_emitted,
        capsule_attachable: capsule_attachable,
        automatic_rewrite_enabled: automatic_rewrite_enabled
    };
}

fn port_manifest_print(m: &PortManifest) -> i64 {
    print("port manifest:");
    print("source_language:");
    print(m.source_language);
    print("target_language:");
    print(m.target_language);
    print("planner_schema:");
    print(m.planner_schema);
    print("source_path:");
    print(m.source_path);
    print("plan_path:");
    print(m.plan_path);
    print("scaffold_path:");
    print(m.scaffold_path);
    print("finding_count:");
    print_int(m.finding_count);
    print("covered_count:");
    print_int(m.covered_count);
    print("partial_count:");
    print_int(m.partial_count);
    print("blocker_count:");
    print_int(m.blocker_count);
    print("target_count:");
    print_int(m.target_count);
    print("suggested_import_count:");
    print_int(m.suggested_import_count);
    print("scaffold_emitted:");
    print_int(m.scaffold_emitted);
    print("capsule_attachable:");
    print_int(m.capsule_attachable);
    print("automatic_rewrite_enabled:");
    print_int(m.automatic_rewrite_enabled);
    return 0;
}

fn port_manifest_emit_jsonl(m: &PortManifest) -> i64 {
    emit_json_run_meta(
        m.source_path,
        "nucleor_port",
        "nuc::port::manifest",
        m.planner_schema,
        m.finding_count,
        m.target_count,
        m.target_language
    );
    emit_json_metric_i64("covered_count", m.covered_count);
    emit_json_metric_i64("partial_count", m.partial_count);
    emit_json_metric_i64("blocker_count", m.blocker_count);
    emit_json_metric_i64("suggested_import_count", m.suggested_import_count);
    emit_json_metric_i64("scaffold_emitted", m.scaffold_emitted);
    emit_json_metric_i64("capsule_attachable", m.capsule_attachable);
    emit_json_metric_i64("automatic_rewrite_enabled", m.automatic_rewrite_enabled);
    return 0;
}

fn port_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native port engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn port_native_available() -> i64 {
    return 0;
}
