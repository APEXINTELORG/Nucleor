// Probe NUC-FEEDBACK-010 v3: faithful reproduction with 10-field struct + ref access
struct ShapeDtypeContract {
    contract_schema: str,
    shape_mode: str,
    dtype_policy_schema: str,
    storage_dtype_count: i64,
    dtype_metadata_count: i64,
    v1_dtype_count: i64,
    quantized_dtype_count: i64,
    runtime_shape_count: i64,
    static_shape_count: i64,
    accumulator_rule_count: i64,
}

fn shape_dtype_contract_print(c: &ShapeDtypeContract) -> i64 {
    print(c.contract_schema);
    print_int(c.static_shape_count);
    return 0;
}

fn main() -> i64 {
    let c: ShapeDtypeContract = ShapeDtypeContract {
        contract_schema: "v0",
        shape_mode: "runtime",
        dtype_policy_schema: "explicit",
        storage_dtype_count: 3,
        dtype_metadata_count: 19,
        v1_dtype_count: 8,
        quantized_dtype_count: 3,
        runtime_shape_count: 5,
        static_shape_count: 0,
        accumulator_rule_count: 6,
    };
    shape_dtype_contract_print(&c);
    return 0;
}
