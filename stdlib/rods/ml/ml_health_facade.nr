// rods/ml/ml_health_facade — ML Suite preflight / health check contract (compiler, LLVM, parity summary, NCAP verification)
//
import "stdlib/rods/jsonl.nr"

// ml_health_facade.nr - ML Suite health/preflight manifest.
//
// This intentionally does not define a top-level `nuc doctor` command. The main
// Nucleor repository owns that router surface. This rod records ML-suite-specific
// checks that can later plug into `nuc doctor --ml-suite`.

#[repr(C)]
struct MlHealthManifest {
    suite_name: str,
    health_schema: str,
    runtime_mode: str,
    compiler_check_required: i64,
    llvm_check_required: i64,
    python_reference_check_required: i64,
    parity_summary_check_required: i64,
    source_hash_check_required: i64,
    capsule_verify_check_required: i64,
    product_zero_python_runtime: i64,
    warning_count: i64,
    failure_count: i64
}

fn ml_health_manifest(
    suite_name: str,
    health_schema: str,
    runtime_mode: str,
    compiler_check_required: i64,
    llvm_check_required: i64,
    python_reference_check_required: i64,
    parity_summary_check_required: i64,
    source_hash_check_required: i64,
    capsule_verify_check_required: i64,
    product_zero_python_runtime: i64,
    warning_count: i64,
    failure_count: i64
) -> MlHealthManifest {
    return MlHealthManifest {
        suite_name: suite_name,
        health_schema: health_schema,
        runtime_mode: runtime_mode,
        compiler_check_required: compiler_check_required,
        llvm_check_required: llvm_check_required,
        python_reference_check_required: python_reference_check_required,
        parity_summary_check_required: parity_summary_check_required,
        source_hash_check_required: source_hash_check_required,
        capsule_verify_check_required: capsule_verify_check_required,
        product_zero_python_runtime: product_zero_python_runtime,
        warning_count: warning_count,
        failure_count: failure_count
    };
}

fn ml_health_manifest_print(m: &MlHealthManifest) -> i64 {
    print("ml health manifest:");
    print("suite_name:");
    print(m.suite_name);
    print("health_schema:");
    print(m.health_schema);
    print("runtime_mode:");
    print(m.runtime_mode);
    print("compiler_check_required:");
    print_int(m.compiler_check_required);
    print("llvm_check_required:");
    print_int(m.llvm_check_required);
    print("python_reference_check_required:");
    print_int(m.python_reference_check_required);
    print("parity_summary_check_required:");
    print_int(m.parity_summary_check_required);
    print("source_hash_check_required:");
    print_int(m.source_hash_check_required);
    print("capsule_verify_check_required:");
    print_int(m.capsule_verify_check_required);
    print("product_zero_python_runtime:");
    print_int(m.product_zero_python_runtime);
    print("warning_count:");
    print_int(m.warning_count);
    print("failure_count:");
    print_int(m.failure_count);
    return 0;
}

fn ml_health_manifest_emit_jsonl(m: &MlHealthManifest) -> i64 {
    emit_json_run_meta(
        m.suite_name,
        "nucleor_ml_health",
        "nuc::ml_health::manifest",
        m.health_schema,
        m.warning_count,
        m.failure_count,
        m.runtime_mode
    );
    emit_json_metric_i64("compiler_check_required", m.compiler_check_required);
    emit_json_metric_i64("llvm_check_required", m.llvm_check_required);
    emit_json_metric_i64("python_reference_check_required", m.python_reference_check_required);
    emit_json_metric_i64("parity_summary_check_required", m.parity_summary_check_required);
    emit_json_metric_i64("source_hash_check_required", m.source_hash_check_required);
    emit_json_metric_i64("capsule_verify_check_required", m.capsule_verify_check_required);
    emit_json_metric_i64("product_zero_python_runtime", m.product_zero_python_runtime);
    return 0;
}

fn ml_health_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}
