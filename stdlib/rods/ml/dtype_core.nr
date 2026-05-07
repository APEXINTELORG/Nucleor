// dtype_core.nr - initial dtype and numeric policy surface for Nucleor ML Suite.
//
// This file intentionally models dtype as explicit metadata instead of hiding
// numeric behavior behind a single carrier. The current compiler supports
// native width-suffixed numerics and f64 vectors; this facade keeps the public
// API ready for f16/bf16/f32/f64, complex, decimal, and quantized kernels.

fn dtype_bool() -> i64 { return 1; }
fn dtype_i8() -> i64 { return 10; }
fn dtype_i16() -> i64 { return 11; }
fn dtype_i32() -> i64 { return 12; }
fn dtype_i64() -> i64 { return 13; }
fn dtype_u8() -> i64 { return 20; }
fn dtype_u16() -> i64 { return 21; }
fn dtype_u32() -> i64 { return 22; }
fn dtype_u64() -> i64 { return 23; }
fn dtype_f16() -> i64 { return 30; }
fn dtype_bf16() -> i64 { return 31; }
fn dtype_f32() -> i64 { return 32; }
fn dtype_f64() -> i64 { return 33; }
fn dtype_complex64() -> i64 { return 40; }
fn dtype_complex128() -> i64 { return 41; }
fn dtype_decimal() -> i64 { return 50; }
fn dtype_qint8() -> i64 { return 60; }
fn dtype_qint4() -> i64 { return 61; }
fn dtype_nf4() -> i64 { return 62; }

fn policy_strict() -> i64 { return 1; }
fn policy_fast() -> i64 { return 2; }
fn policy_mixed_precision() -> i64 { return 3; }
fn policy_quantized() -> i64 { return 4; }
fn policy_cert() -> i64 { return 5; }

fn dtype_name(dtype: i64) -> str {
    if dtype == dtype_bool() { return "bool"; };
    if dtype == dtype_i8() { return "i8"; };
    if dtype == dtype_i16() { return "i16"; };
    if dtype == dtype_i32() { return "i32"; };
    if dtype == dtype_i64() { return "i64"; };
    if dtype == dtype_u8() { return "u8"; };
    if dtype == dtype_u16() { return "u16"; };
    if dtype == dtype_u32() { return "u32"; };
    if dtype == dtype_u64() { return "u64"; };
    if dtype == dtype_f16() { return "f16"; };
    if dtype == dtype_bf16() { return "bf16"; };
    if dtype == dtype_f32() { return "f32"; };
    if dtype == dtype_f64() { return "f64"; };
    if dtype == dtype_complex64() { return "complex64"; };
    if dtype == dtype_complex128() { return "complex128"; };
    if dtype == dtype_decimal() { return "decimal"; };
    if dtype == dtype_qint8() { return "qint8"; };
    if dtype == dtype_qint4() { return "qint4"; };
    if dtype == dtype_nf4() { return "nf4"; };
    return "unknown";
}

fn policy_name(policy: i64) -> str {
    if policy == policy_strict() { return "strict"; };
    if policy == policy_fast() { return "fast"; };
    if policy == policy_mixed_precision() { return "mixed_precision"; };
    if policy == policy_quantized() { return "quantized"; };
    if policy == policy_cert() { return "cert"; };
    return "unknown";
}

fn dtype_size_bytes(dtype: i64) -> i64 {
    if dtype == dtype_bool() { return 1; };
    if dtype == dtype_i8() { return 1; };
    if dtype == dtype_u8() { return 1; };
    if dtype == dtype_i16() { return 2; };
    if dtype == dtype_u16() { return 2; };
    if dtype == dtype_f16() { return 2; };
    if dtype == dtype_bf16() { return 2; };
    if dtype == dtype_i32() { return 4; };
    if dtype == dtype_u32() { return 4; };
    if dtype == dtype_f32() { return 4; };
    if dtype == dtype_complex64() { return 8; };
    if dtype == dtype_i64() { return 8; };
    if dtype == dtype_u64() { return 8; };
    if dtype == dtype_f64() { return 8; };
    if dtype == dtype_complex128() { return 16; };
    if dtype == dtype_decimal() { return 16; };
    if dtype == dtype_qint8() { return 1; };
    if dtype == dtype_qint4() { return 1; };
    if dtype == dtype_nf4() { return 1; };
    return 0;
}

fn dtype_is_float(dtype: i64) -> bool {
    if dtype == dtype_f16() { return true; };
    if dtype == dtype_bf16() { return true; };
    if dtype == dtype_f32() { return true; };
    if dtype == dtype_f64() { return true; };
    return false;
}

fn dtype_is_integer(dtype: i64) -> bool {
    if dtype == dtype_i8() { return true; };
    if dtype == dtype_i16() { return true; };
    if dtype == dtype_i32() { return true; };
    if dtype == dtype_i64() { return true; };
    if dtype == dtype_u8() { return true; };
    if dtype == dtype_u16() { return true; };
    if dtype == dtype_u32() { return true; };
    if dtype == dtype_u64() { return true; };
    return false;
}

fn dtype_is_quantized(dtype: i64) -> bool {
    if dtype == dtype_qint8() { return true; };
    if dtype == dtype_qint4() { return true; };
    if dtype == dtype_nf4() { return true; };
    return false;
}

fn dtype_default_accumulator(dtype: i64) -> i64 {
    if dtype == dtype_f16() { return dtype_f32(); };
    if dtype == dtype_bf16() { return dtype_f32(); };
    if dtype == dtype_f32() { return dtype_f32(); };
    if dtype == dtype_f64() { return dtype_f64(); };
    if dtype == dtype_qint8() { return dtype_i32(); };
    if dtype == dtype_qint4() { return dtype_i32(); };
    if dtype == dtype_nf4() { return dtype_f32(); };
    if dtype_is_integer(dtype) { return dtype_i64(); };
    return dtype;
}
