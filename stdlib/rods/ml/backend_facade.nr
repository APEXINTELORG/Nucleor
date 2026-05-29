// rods/ml/backend_facade — Backend dispatch accounting contract (scalar fallback / CPU / GPU / fused / external backend counts)
//
import "stdlib/rods/jsonl.nr"

// backend_facade.nr - first backend dispatch accounting surface.
//
// The MVP is not a kernel backend implementation. It records the dispatch facts
// required before a benchmark can make a credible speed claim.

#[repr(C)]
struct BackendManifest {
    plan_name: str,
    active_backend: str,
    device: str,
    kernel_family: str,
    dtype_policy: str,
    dispatch_count: i64,
    external_backend_count: i64,
    scalar_fallback_count: i64,
    cpu_backend_count: i64,
    gpu_backend_count: i64,
    fused_kernel_count: i64,
    zero_python_runtime: i64
}

fn backend_manifest(
    plan_name: str,
    active_backend: str,
    device: str,
    kernel_family: str,
    dtype_policy: str,
    dispatch_count: i64,
    external_backend_count: i64,
    scalar_fallback_count: i64,
    cpu_backend_count: i64,
    gpu_backend_count: i64,
    fused_kernel_count: i64,
    zero_python_runtime: i64
) -> BackendManifest {
    return BackendManifest {
        plan_name: plan_name,
        active_backend: active_backend,
        device: device,
        kernel_family: kernel_family,
        dtype_policy: dtype_policy,
        dispatch_count: dispatch_count,
        external_backend_count: external_backend_count,
        scalar_fallback_count: scalar_fallback_count,
        cpu_backend_count: cpu_backend_count,
        gpu_backend_count: gpu_backend_count,
        fused_kernel_count: fused_kernel_count,
        zero_python_runtime: zero_python_runtime
    };
}

fn backend_manifest_print(m: &BackendManifest) -> i64 {
    print("backend manifest:");
    print("plan_name:");
    print(m.plan_name);
    print("active_backend:");
    print(m.active_backend);
    print("device:");
    print(m.device);
    print("kernel_family:");
    print(m.kernel_family);
    print("dtype_policy:");
    print(m.dtype_policy);
    print("dispatch_count:");
    print_int(m.dispatch_count);
    print("external_backend_count:");
    print_int(m.external_backend_count);
    print("scalar_fallback_count:");
    print_int(m.scalar_fallback_count);
    print("cpu_backend_count:");
    print_int(m.cpu_backend_count);
    print("gpu_backend_count:");
    print_int(m.gpu_backend_count);
    print("fused_kernel_count:");
    print_int(m.fused_kernel_count);
    print("zero_python_runtime:");
    print_int(m.zero_python_runtime);
    return 0;
}

fn backend_manifest_emit_jsonl(m: &BackendManifest) -> i64 {
    emit_json_run_meta(
        m.plan_name,
        "nucleor_backend",
        "nuc::backend::manifest",
        m.dtype_policy,
        m.dispatch_count,
        m.scalar_fallback_count,
        m.active_backend
    );
    emit_json_metric_i64("external_backend_count", m.external_backend_count);
    emit_json_metric_i64("cpu_backend_count", m.cpu_backend_count);
    emit_json_metric_i64("gpu_backend_count", m.gpu_backend_count);
    emit_json_metric_i64("fused_kernel_count", m.fused_kernel_count);
    emit_json_metric_i64("zero_python_runtime", m.zero_python_runtime);
    return 0;
}

fn backend_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native backend engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn backend_native_available() -> i64 {
    return 0;
}
