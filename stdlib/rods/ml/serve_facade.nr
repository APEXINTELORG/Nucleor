// rods/ml/serve_facade — nuc serve package contract (model format, quantization, tokenizer, backend, context window, batch size)
// Maturity: CONTRACT-ONLY — records manifest/contract metadata; no native engine or runtime is linked behind it. Enforced by serve_native_available()==0 (HON-1).
//
import "stdlib/rods/jsonl.nr"

// serve_facade.nr - first nuc-serve style manifest surface.
//
// The MVP records the deployment-facing facts that should eventually be baked
// into a signed .ncap: model format, quantization, tokenizer, backend,
// context window, batch size, port, and route count.

#[repr(C)]
struct ServeManifest {
    model_name: str,
    model_format: str,
    quantization: str,
    tokenizer: str,
    backend: str,
    context_window: i64,
    max_batch: i64,
    port: i64,
    route_count: i64,
    external_backend_count: i64
}

fn serve_manifest(
    model_name: str,
    model_format: str,
    quantization: str,
    tokenizer: str,
    backend: str,
    context_window: i64,
    max_batch: i64,
    port: i64,
    route_count: i64,
    external_backend_count: i64
) -> ServeManifest {
    return ServeManifest {
        model_name: model_name,
        model_format: model_format,
        quantization: quantization,
        tokenizer: tokenizer,
        backend: backend,
        context_window: context_window,
        max_batch: max_batch,
        port: port,
        route_count: route_count,
        external_backend_count: external_backend_count
    };
}

fn serve_manifest_print(m: &ServeManifest) -> i64 {
    print("serve manifest:");
    print("model_name:");
    print(m.model_name);
    print("model_format:");
    print(m.model_format);
    print("quantization:");
    print(m.quantization);
    print("tokenizer:");
    print(m.tokenizer);
    print("backend:");
    print(m.backend);
    print("context_window:");
    print_int(m.context_window);
    print("max_batch:");
    print_int(m.max_batch);
    print("port:");
    print_int(m.port);
    print("route_count:");
    print_int(m.route_count);
    print("external_backend_count:");
    print_int(m.external_backend_count);
    return 0;
}

fn serve_manifest_emit_jsonl(m: &ServeManifest) -> i64 {
    emit_json_run_meta(
        m.model_name,
        "nucleor_serve",
        "nuc::serve::manifest",
        m.quantization,
        m.context_window,
        m.max_batch,
        m.backend
    );
    emit_json_metric_i64("port", m.port);
    emit_json_metric_i64("route_count", m.route_count);
    emit_json_metric_i64("external_backend_count", m.external_backend_count);
    return 0;
}

fn serve_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native serve engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn serve_native_available() -> i64 {
    return 0;
}
