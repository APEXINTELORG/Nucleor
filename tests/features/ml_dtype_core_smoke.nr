import "stdlib/rods/ml/dtype_core.nr"

// ml_dtype_core_smoke — exercises dtype tag + accumulator policy + numeric
// policy helpers from stdlib/rods/ml/dtype_core.nr.

fn main() -> i32 {
    let mut fail: i64 = 0;

    if dtype_size_bytes(dtype_f64()) != 8 { print("FAIL dtype f64 size"); fail = fail + 1; };
    if dtype_size_bytes(dtype_f32()) != 4 { print("FAIL dtype f32 size"); fail = fail + 1; };
    if dtype_size_bytes(dtype_i64()) != 8 { print("FAIL dtype i64 size"); fail = fail + 1; };
    if dtype_size_bytes(dtype_i32()) != 4 { print("FAIL dtype i32 size"); fail = fail + 1; };
    if dtype_size_bytes(dtype_bf16()) != 2 { print("FAIL dtype bf16 size"); fail = fail + 1; };

    if dtype_default_accumulator(dtype_f64()) != dtype_f64() { print("FAIL acc f64"); fail = fail + 1; };
    if dtype_default_accumulator(dtype_bf16()) != dtype_f32() { print("FAIL acc bf16->f32"); fail = fail + 1; };
    if dtype_default_accumulator(dtype_qint8()) != dtype_i32() { print("FAIL acc qint8->i32"); fail = fail + 1; };

    if policy_strict() == policy_fast() { print("FAIL policy distinct"); fail = fail + 1; };

    if fail == 0 {
        print("OK ml_dtype_core_smoke");
        return 0;
    };
    print("FAIL ml_dtype_core_smoke");
    return 1;
}
