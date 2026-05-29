// rods/ml/onnx_facade — ONNX model loader manifest contract (graph format, opset, external runtime accounting)
// Maturity: CONTRACT-ONLY — records manifest/contract metadata; no native engine or runtime is linked behind it. Enforced by onnx_native_available()==0 (HON-1).
//
import "stdlib/rods/jsonl.nr"

// onnx_facade.nr - ONNX model-interchange manifest surface.
//
// This MVP records ONNX deployment metadata and external runtime accounting.
// It does not claim native graph execution yet.

#[repr(C)]
struct OnnxManifest {
    model_name: str,
    opset_version: i64,
    input_count: i64,
    output_count: i64,
    initializer_count: i64,
    node_count: i64,
    shape_contract_count: i64,
    static_dim_count: i64,
    dynamic_axis_count: i64,
    dtype_policy_count: i64,
    dtype_constraint_count: i64,
    unsupported_op_count: i64,
    execution_provider_count: i64,
    external_runtime_count: i64
}

fn onnx_manifest(
    model_name: str,
    opset_version: i64,
    input_count: i64,
    output_count: i64,
    initializer_count: i64,
    node_count: i64,
    shape_contract_count: i64,
    static_dim_count: i64,
    dynamic_axis_count: i64,
    dtype_policy_count: i64,
    dtype_constraint_count: i64,
    unsupported_op_count: i64,
    execution_provider_count: i64,
    external_runtime_count: i64
) -> OnnxManifest {
    return OnnxManifest {
        model_name: model_name,
        opset_version: opset_version,
        input_count: input_count,
        output_count: output_count,
        initializer_count: initializer_count,
        node_count: node_count,
        shape_contract_count: shape_contract_count,
        static_dim_count: static_dim_count,
        dynamic_axis_count: dynamic_axis_count,
        dtype_policy_count: dtype_policy_count,
        dtype_constraint_count: dtype_constraint_count,
        unsupported_op_count: unsupported_op_count,
        execution_provider_count: execution_provider_count,
        external_runtime_count: external_runtime_count
    };
}

fn onnx_manifest_print(m: &OnnxManifest) -> i64 {
    print("onnx manifest:");
    print("model_name:");
    print(m.model_name);
    print("opset_version:");
    print_int(m.opset_version);
    print("input_count:");
    print_int(m.input_count);
    print("output_count:");
    print_int(m.output_count);
    print("initializer_count:");
    print_int(m.initializer_count);
    print("node_count:");
    print_int(m.node_count);
    print("shape_contract_count:");
    print_int(m.shape_contract_count);
    print("static_dim_count:");
    print_int(m.static_dim_count);
    print("dynamic_axis_count:");
    print_int(m.dynamic_axis_count);
    print("dtype_policy_count:");
    print_int(m.dtype_policy_count);
    print("dtype_constraint_count:");
    print_int(m.dtype_constraint_count);
    print("unsupported_op_count:");
    print_int(m.unsupported_op_count);
    print("execution_provider_count:");
    print_int(m.execution_provider_count);
    print("external_runtime_count:");
    print_int(m.external_runtime_count);
    return 0;
}

fn onnx_manifest_emit_jsonl(m: &OnnxManifest) -> i64 {
    emit_json_run_meta(
        m.model_name,
        "nucleor_onnx",
        "nuc::onnx::manifest",
        "mixed_tensor_contract",
        m.input_count,
        m.output_count,
        "metadata_first_external_runtime_accounted"
    );
    emit_json_metric_i64("opset_version", m.opset_version);
    emit_json_metric_i64("input_count", m.input_count);
    emit_json_metric_i64("output_count", m.output_count);
    emit_json_metric_i64("initializer_count", m.initializer_count);
    emit_json_metric_i64("node_count", m.node_count);
    emit_json_metric_i64("shape_contract_count", m.shape_contract_count);
    emit_json_metric_i64("static_dim_count", m.static_dim_count);
    emit_json_metric_i64("dynamic_axis_count", m.dynamic_axis_count);
    emit_json_metric_i64("dtype_policy_count", m.dtype_policy_count);
    emit_json_metric_i64("dtype_constraint_count", m.dtype_constraint_count);
    emit_json_metric_i64("unsupported_op_count", m.unsupported_op_count);
    emit_json_metric_i64("execution_provider_count", m.execution_provider_count);
    emit_json_metric_i64("external_runtime_count", m.external_runtime_count);
    return 0;
}

fn onnx_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native onnx engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn onnx_native_available() -> i64 {
    return 0;
}
