import "stdlib/rods/ml/contract_facade.nr"

fn main() -> i64 {
    let contract = shape_dtype_contract(
        "shape_dtype_contract_v0",
        "runtime_shape2_future_static_shapes",
        "explicit_dtype_metadata_v0",
        3,
        19,
        8,
        3,
        5,
        0,
        6
    );

    let left = shape2(2, 3);
    let right = shape2(3, 4);
    let same_a = shape2(2, 3);
    let same_b = shape2(2, 3);
    let mismatch = shape2(4, 2);

    let mut matmul_rule_passed = 0;
    if shape2_can_matmul(&left, &right) { matmul_rule_passed = 1; };

    let mut same_rule_passed = 0;
    if shape2_same(&same_a, &same_b) { same_rule_passed = 1; };

    let mut mismatch_rule_detected = 0;
    if !shape2_same(&same_a, &mismatch) { mismatch_rule_detected = 1; };

    let mut accumulator_rule_passed = 0;
    if dtype_default_accumulator(dtype_bf16()) == dtype_f32() {
        if dtype_default_accumulator(dtype_nf4()) == dtype_f32() {
            if dtype_default_accumulator(dtype_qint8()) == dtype_i32() {
                accumulator_rule_passed = 1;
            };
        };
    };

    let mut passed = 1;
    if matmul_rule_passed != 1 { passed = 0; };
    if same_rule_passed != 1 { passed = 0; };
    if mismatch_rule_detected != 1 { passed = 0; };
    if accumulator_rule_passed != 1 { passed = 0; };
    let compile_time_shape_count = 0;
    if compile_time_shape_count != 0 { passed = 0; };

    shape_dtype_contract_print(&contract);
    shape_dtype_contract_emit_jsonl(
        &contract,
        matmul_rule_passed,
        same_rule_passed,
        mismatch_rule_detected,
        accumulator_rule_passed
    );
    shape_dtype_contract_emit_status(passed);
    if contract_native_available() != 0 { panic("contract_facade falsely advertises a native backend"); };
    return 0;
}
