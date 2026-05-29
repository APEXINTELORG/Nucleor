// rods/ml/model_io_facade — nuc serve model-loader contract (.ncap, GGUF, safetensors, ONNX, tokenizer, quantization formats)
//
import "stdlib/rods/jsonl.nr"

// model_io_facade.nr - model loading and format-support manifest.
//
// The MVP declares the model I/O surface needed by `nuc serve`: model formats,
// tokenizer formats, quantization formats, streaming/mmap eligibility, and
// external loader accounting.

#[repr(C)]
struct ModelIoManifest {
    loader_name: str,
    model_format_set: str,
    tokenizer_format_set: str,
    quantization_format_set: str,
    loader_policy: str,
    model_format_count: i64,
    tokenizer_format_count: i64,
    quantization_format_count: i64,
    mmap_supported: i64,
    streaming_supported: i64,
    external_loader_count: i64,
    zero_python_runtime: i64
}

fn model_io_manifest(
    loader_name: str,
    model_format_set: str,
    tokenizer_format_set: str,
    quantization_format_set: str,
    loader_policy: str,
    model_format_count: i64,
    tokenizer_format_count: i64,
    quantization_format_count: i64,
    mmap_supported: i64,
    streaming_supported: i64,
    external_loader_count: i64,
    zero_python_runtime: i64
) -> ModelIoManifest {
    return ModelIoManifest {
        loader_name: loader_name,
        model_format_set: model_format_set,
        tokenizer_format_set: tokenizer_format_set,
        quantization_format_set: quantization_format_set,
        loader_policy: loader_policy,
        model_format_count: model_format_count,
        tokenizer_format_count: tokenizer_format_count,
        quantization_format_count: quantization_format_count,
        mmap_supported: mmap_supported,
        streaming_supported: streaming_supported,
        external_loader_count: external_loader_count,
        zero_python_runtime: zero_python_runtime
    };
}

fn model_io_manifest_print(m: &ModelIoManifest) -> i64 {
    print("model io manifest:");
    print("loader_name:");
    print(m.loader_name);
    print("model_format_set:");
    print(m.model_format_set);
    print("tokenizer_format_set:");
    print(m.tokenizer_format_set);
    print("quantization_format_set:");
    print(m.quantization_format_set);
    print("loader_policy:");
    print(m.loader_policy);
    print("model_format_count:");
    print_int(m.model_format_count);
    print("tokenizer_format_count:");
    print_int(m.tokenizer_format_count);
    print("quantization_format_count:");
    print_int(m.quantization_format_count);
    print("mmap_supported:");
    print_int(m.mmap_supported);
    print("streaming_supported:");
    print_int(m.streaming_supported);
    print("external_loader_count:");
    print_int(m.external_loader_count);
    print("zero_python_runtime:");
    print_int(m.zero_python_runtime);
    return 0;
}

fn model_io_manifest_emit_jsonl(m: &ModelIoManifest) -> i64 {
    emit_json_run_meta(
        m.loader_name,
        "nucleor_model_io",
        "nuc::model_io::manifest",
        m.model_format_set,
        m.model_format_count,
        m.quantization_format_count,
        m.loader_policy
    );
    emit_json_metric_i64("tokenizer_format_count", m.tokenizer_format_count);
    emit_json_metric_i64("mmap_supported", m.mmap_supported);
    emit_json_metric_i64("streaming_supported", m.streaming_supported);
    emit_json_metric_i64("external_loader_count", m.external_loader_count);
    emit_json_metric_i64("zero_python_runtime", m.zero_python_runtime);
    return 0;
}

fn model_io_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native model_io engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn model_io_native_available() -> i64 {
    return 0;
}
