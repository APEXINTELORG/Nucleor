// rods/ml/contract_facade — Runtime shape/dtype contract (compile_time_shape_assertion_count = 0 boundary)
//
import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/jsonl.nr"

// contract_facade.nr - honest shape and dtype capability contract.
//
// This surface records what is real today: runtime Shape2 checks and explicit
// dtype metadata. It keeps compile-time shape claims at zero until the language
// grows type-level shapes.

#[repr(C)]
struct ShapeDtypeContract {
    contract_schema: str,
    shape_mode: str,
    dtype_policy_schema: str,
    storage_dtype_count: i64,
    dtype_metadata_count: i64,
    v1_dtype_count: i64,
    quantized_dtype_count: i64,
    runtime_shape_count: i64,
    ct_shape_count: i64,
    accumulator_rule_count: i64
}

fn shape_dtype_contract(
    contract_schema: str,
    shape_mode: str,
    dtype_policy_schema: str,
    storage_dtype_count: i64,
    dtype_metadata_count: i64,
    v1_dtype_count: i64,
    quantized_dtype_count: i64,
    runtime_shape_count: i64,
    ct_shape_count: i64,
    accumulator_rule_count: i64
) -> ShapeDtypeContract {
    return ShapeDtypeContract {
        contract_schema: contract_schema,
        shape_mode: shape_mode,
        dtype_policy_schema: dtype_policy_schema,
        storage_dtype_count: storage_dtype_count,
        dtype_metadata_count: dtype_metadata_count,
        v1_dtype_count: v1_dtype_count,
        quantized_dtype_count: quantized_dtype_count,
        runtime_shape_count: runtime_shape_count,
        ct_shape_count: ct_shape_count,
        accumulator_rule_count: accumulator_rule_count
    };
}

fn shape_dtype_contract_print(c: &ShapeDtypeContract) -> i64 {
    print("shape dtype contract:");
    print("contract_schema:");
    print(c.contract_schema);
    print("shape_mode:");
    print(c.shape_mode);
    print("dtype_policy_schema:");
    print(c.dtype_policy_schema);
    print("active_tensor_storage_dtype_count:");
    print_int(c.storage_dtype_count);
    print("dtype_metadata_count:");
    print_int(c.dtype_metadata_count);
    print("v1_priority_dtype_count:");
    print_int(c.v1_dtype_count);
    print("quantized_metadata_count:");
    print_int(c.quantized_dtype_count);
    print("runtime_shape_assertion_count:");
    print_int(c.runtime_shape_count);
    print("compile_time_shape_assertion_count:");
    print_int(c.ct_shape_count);
    print("accumulator_rule_count:");
    print_int(c.accumulator_rule_count);
    return 0;
}

fn shape_dtype_contract_emit_jsonl(
    c: &ShapeDtypeContract,
    matmul_rule_passed: i64,
    same_rule_passed: i64,
    mismatch_rule_detected: i64,
    accumulator_rule_passed: i64
) -> i64 {
    emit_json_run_meta(
        "nucleor_ml_suite",
        "nucleor_contract",
        "nuc::contract::shape_dtype",
        c.contract_schema,
        c.storage_dtype_count,
        c.dtype_metadata_count,
        c.shape_mode
    );
    emit_json_metric_i64("v1_priority_dtype_count", c.v1_dtype_count);
    emit_json_metric_i64("quantized_metadata_count", c.quantized_dtype_count);
    emit_json_metric_i64("runtime_shape_assertion_count", c.runtime_shape_count);
    emit_json_metric_i64("compile_time_shape_assertion_count", c.ct_shape_count);
    emit_json_metric_i64("accumulator_rule_count", c.accumulator_rule_count);
    emit_json_metric_i64("matmul_rule_passed", matmul_rule_passed);
    emit_json_metric_i64("same_rule_passed", same_rule_passed);
    emit_json_metric_i64("mismatch_rule_detected", mismatch_rule_detected);
    emit_json_metric_i64("accumulator_rule_passed", accumulator_rule_passed);
    return 0;
}

fn shape_dtype_contract_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}
