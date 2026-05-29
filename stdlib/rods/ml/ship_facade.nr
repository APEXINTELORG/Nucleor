// rods/ml/ship_facade — nuc ship packaging contract (source/compiler/rod-lock/artifact-contract/agent-trace requirements)
// Maturity: CONTRACT-ONLY — records manifest/contract metadata; no native engine or runtime is linked behind it. Enforced by ship_native_available()==0 (HON-1).
//
import "stdlib/rods/jsonl.nr"

// ship_facade.nr - signed/unsigned artifact packaging manifest.
//
// The MVP records the requirements for reproducible package shipping. It keeps
// unsigned status explicit until real key management and signature verification
// are implemented.

#[repr(C)]
struct ShipManifest {
    package_name: str,
    input_kind: str,
    output_kind: str,
    capsule_schema: str,
    signing_mode: str,
    signature_scheme: str,
    source_hash_required: i64,
    compiler_hash_required: i64,
    rod_lock_required: i64,
    artifact_contract_required: i64,
    agent_trace_required: i64,
    deterministic_build: i64,
    zero_python_runtime: i64,
    signed: i64,
    external_dependency_count: i64
}

fn ship_manifest(
    package_name: str,
    input_kind: str,
    output_kind: str,
    capsule_schema: str,
    signing_mode: str,
    signature_scheme: str,
    source_hash_required: i64,
    compiler_hash_required: i64,
    rod_lock_required: i64,
    artifact_contract_required: i64,
    agent_trace_required: i64,
    deterministic_build: i64,
    zero_python_runtime: i64,
    signed: i64,
    external_dependency_count: i64
) -> ShipManifest {
    return ShipManifest {
        package_name: package_name,
        input_kind: input_kind,
        output_kind: output_kind,
        capsule_schema: capsule_schema,
        signing_mode: signing_mode,
        signature_scheme: signature_scheme,
        source_hash_required: source_hash_required,
        compiler_hash_required: compiler_hash_required,
        rod_lock_required: rod_lock_required,
        artifact_contract_required: artifact_contract_required,
        agent_trace_required: agent_trace_required,
        deterministic_build: deterministic_build,
        zero_python_runtime: zero_python_runtime,
        signed: signed,
        external_dependency_count: external_dependency_count
    };
}

fn ship_manifest_print(m: &ShipManifest) -> i64 {
    print("ship manifest:");
    print("package_name:");
    print(m.package_name);
    print("input_kind:");
    print(m.input_kind);
    print("output_kind:");
    print(m.output_kind);
    print("capsule_schema:");
    print(m.capsule_schema);
    print("signing_mode:");
    print(m.signing_mode);
    print("signature_scheme:");
    print(m.signature_scheme);
    print("source_hash_required:");
    print_int(m.source_hash_required);
    print("compiler_hash_required:");
    print_int(m.compiler_hash_required);
    print("rod_lock_required:");
    print_int(m.rod_lock_required);
    print("artifact_contract_required:");
    print_int(m.artifact_contract_required);
    print("agent_trace_required:");
    print_int(m.agent_trace_required);
    print("deterministic_build:");
    print_int(m.deterministic_build);
    print("zero_python_runtime:");
    print_int(m.zero_python_runtime);
    print("signed:");
    print_int(m.signed);
    print("external_dependency_count:");
    print_int(m.external_dependency_count);
    return 0;
}

fn ship_manifest_emit_jsonl(m: &ShipManifest) -> i64 {
    emit_json_run_meta(
        m.package_name,
        "nucleor_ship",
        "nuc::ship::manifest",
        m.signature_scheme,
        m.signed,
        m.external_dependency_count,
        m.signing_mode
    );
    emit_json_metric_i64("source_hash_required", m.source_hash_required);
    emit_json_metric_i64("compiler_hash_required", m.compiler_hash_required);
    emit_json_metric_i64("rod_lock_required", m.rod_lock_required);
    emit_json_metric_i64("artifact_contract_required", m.artifact_contract_required);
    emit_json_metric_i64("agent_trace_required", m.agent_trace_required);
    emit_json_metric_i64("deterministic_build", m.deterministic_build);
    emit_json_metric_i64("zero_python_runtime", m.zero_python_runtime);
    return 0;
}

fn ship_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native ship engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn ship_native_available() -> i64 {
    return 0;
}
