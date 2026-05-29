// rods/ml/bench_facade — nuc bench telemetry contract (wall time, peak RSS, binary size, dependency count; speed_claim_enabled=0)
// Maturity: CONTRACT-ONLY — records manifest/contract metadata; no native engine or runtime is linked behind it. Enforced by bench_native_available()==0 (HON-1).
//
import "stdlib/rods/jsonl.nr"

// bench_facade.nr - benchmark manifest and evidence contract.
//
// The MVP separates measurement presence from performance claims. Timing and
// memory numbers are volatile local evidence; speed claims stay disabled until
// backend accounting and repeatable benchmark gates mature.

#[repr(C)]
struct BenchManifest {
    suite_name: str,
    report_schema: str,
    timing_method: str,
    measurement_mode: str,
    case_count: i64,
    dependency_count: i64,
    timing_supported: i64,
    peak_memory_supported: i64,
    binary_size_supported: i64,
    backend_accounting_required: i64,
    speed_claim_enabled: i64,
    external_backend_count: i64
}

fn bench_manifest(
    suite_name: str,
    report_schema: str,
    timing_method: str,
    measurement_mode: str,
    case_count: i64,
    dependency_count: i64,
    timing_supported: i64,
    peak_memory_supported: i64,
    binary_size_supported: i64,
    backend_accounting_required: i64,
    speed_claim_enabled: i64,
    external_backend_count: i64
) -> BenchManifest {
    return BenchManifest {
        suite_name: suite_name,
        report_schema: report_schema,
        timing_method: timing_method,
        measurement_mode: measurement_mode,
        case_count: case_count,
        dependency_count: dependency_count,
        timing_supported: timing_supported,
        peak_memory_supported: peak_memory_supported,
        binary_size_supported: binary_size_supported,
        backend_accounting_required: backend_accounting_required,
        speed_claim_enabled: speed_claim_enabled,
        external_backend_count: external_backend_count
    };
}

fn bench_manifest_print(m: &BenchManifest) -> i64 {
    print("bench manifest:");
    print("suite_name:");
    print(m.suite_name);
    print("report_schema:");
    print(m.report_schema);
    print("timing_method:");
    print(m.timing_method);
    print("measurement_mode:");
    print(m.measurement_mode);
    print("case_count:");
    print_int(m.case_count);
    print("dependency_count:");
    print_int(m.dependency_count);
    print("timing_supported:");
    print_int(m.timing_supported);
    print("peak_memory_supported:");
    print_int(m.peak_memory_supported);
    print("binary_size_supported:");
    print_int(m.binary_size_supported);
    print("backend_accounting_required:");
    print_int(m.backend_accounting_required);
    print("speed_claim_enabled:");
    print_int(m.speed_claim_enabled);
    print("external_backend_count:");
    print_int(m.external_backend_count);
    return 0;
}

fn bench_manifest_emit_jsonl(m: &BenchManifest) -> i64 {
    emit_json_run_meta(
        m.suite_name,
        "nucleor_bench",
        "nuc::bench::manifest",
        m.report_schema,
        m.case_count,
        m.dependency_count,
        m.measurement_mode
    );
    emit_json_metric_i64("timing_supported", m.timing_supported);
    emit_json_metric_i64("peak_memory_supported", m.peak_memory_supported);
    emit_json_metric_i64("binary_size_supported", m.binary_size_supported);
    emit_json_metric_i64("backend_accounting_required", m.backend_accounting_required);
    emit_json_metric_i64("speed_claim_enabled", m.speed_claim_enabled);
    emit_json_metric_i64("external_backend_count", m.external_backend_count);
    return 0;
}

fn bench_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native bench engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn bench_native_available() -> i64 {
    return 0;
}
