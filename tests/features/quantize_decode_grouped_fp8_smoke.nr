// helper1 v0859 ML-6/ML-7 - quantize decode, FP8 inference, grouped Q4 smoke.
//
// Locks real callable surfaces for the previously disclosure-only quantize
// gaps: INT8 decode, ternary decode, FP8 decode/GEMV/dot, and grouped
// signed-Q4 decode/GEMV.

import "stdlib/rods/quantize.nr"

fn close_bits(bits: i64, expected: f64, eps: f64) -> i64 {
    let got: f64 = f64_from_bits(bits);
    let d: f64 = got - expected;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d <= eps { return 1; };
    return 0;
}

fn make_matrix_2x2() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(2.0));
    v.push(f64_to_bits(3.0));
    v.push(f64_to_bits(4.0));
    return v;
}

fn make_identity_like_2x2() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(4.0));
    v.push(f64_to_bits(0.0));
    v.push(f64_to_bits(0.0));
    v.push(f64_to_bits(4.0));
    return v;
}

fn make_x2() -> Vec<i64> {
    let mut x: Vec<i64> = Vec::new();
    x.push(f64_to_bits(1.0));
    x.push(f64_to_bits(1.0));
    return x;
}

fn check_supported_table() -> i64 {
    if quant_op_supported("fp8_decode") != 1 { return 1; };
    if quant_op_supported("fp8_gemv") != 1 { return 2; };
    if quant_op_supported("fp8_dot") != 1 { return 4; };
    if quant_op_supported("int8_decode") != 1 { return 8; };
    if quant_op_supported("ternary_decode") != 1 { return 16; };
    if quant_op_supported("grouped_encode") != 1 { return 32; };
    if quant_op_supported("grouped_decode") != 1 { return 64; };
    if quant_op_supported("grouped_gemv") != 1 { return 128; };
    if quant_op_supported("fp8_true_e4m3_bits") != 0 { return 256; };
    return 0;
}

fn check_int8_decode() -> i64 {
    let w: Vec<i64> = make_matrix_2x2();
    let h: i64 = quant_int8_encode(w, 2, 2);
    if h == 0 { return 512; };
    let dec: i64 = quant_int8_decode(h);
    if dec == 0 { return 1024; };
    if vec_len(dec) != 4 { return 2048; };
    if close_bits(vec_get(dec, 0), 1.0, 0.05) != 1 { return 4096; };
    if close_bits(vec_get(dec, 1), 2.0, 0.05) != 1 { return 8192; };
    if close_bits(vec_get(dec, 2), 3.0, 0.05) != 1 { return 16384; };
    if close_bits(vec_get(dec, 3), 4.0, 0.05) != 1 { return 32768; };
    return 0;
}

fn check_ternary_decode() -> i64 {
    let w: Vec<i64> = make_identity_like_2x2();
    let h: i64 = quant_ternary_encode(w, 4);
    if h == 0 { return 65536; };
    let dec: i64 = quant_ternary_decode(h);
    if dec == 0 { return 131072; };
    if vec_len(dec) != 4 { return 262144; };
    if close_bits(vec_get(dec, 0), 2.0, 1e-9) != 1 { return 524288; };
    if close_bits(vec_get(dec, 1), 0.0, 1e-9) != 1 { return 1048576; };
    if close_bits(vec_get(dec, 2), 0.0, 1e-9) != 1 { return 2097152; };
    if close_bits(vec_get(dec, 3), 2.0, 1e-9) != 1 { return 4194304; };
    return 0;
}

fn check_fp8_decode_gemv_dot() -> i64 {
    let w: Vec<i64> = make_matrix_2x2();
    let h: i64 = quant_fp8_encode(w, 4, 2);
    if h == 0 { return 8388608; };
    let dec: i64 = quant_fp8_decode(h);
    if dec == 0 { return 16777216; };
    if vec_len(dec) != 4 { return 33554432; };
    if close_bits(vec_get(dec, 0), 1.0, 0.02) != 1 { return 67108864; };
    if close_bits(vec_get(dec, 3), 4.0, 0.02) != 1 { return 134217728; };
    let x: Vec<i64> = make_x2();
    let y: i64 = quant_fp8_gemv(h, x, 2, 2);
    if y == 0 { return 268435456; };
    if vec_len(y) != 2 { return 536870912; };
    if close_bits(vec_get(y, 0), 3.0, 0.05) != 1 { return 1073741824; };
    if close_bits(vec_get(y, 1), 7.0, 0.05) != 1 { return 2147483648; };
    let dot_bits: i64 = quant_fp8_dot(h, h);
    if close_bits(dot_bits, 30.0, 0.1) != 1 { return 4294967296; };
    return 0;
}

fn check_grouped_decode_gemv() -> i64 {
    let w: Vec<i64> = make_matrix_2x2();
    let h: i64 = quant_grouped_encode(w, 4, 2);
    if h == 0 { return 8589934592; };
    let dec: i64 = quant_grouped_decode(h);
    if dec == 0 { return 17179869184; };
    if vec_len(dec) != 4 { return 34359738368; };
    if close_bits(vec_get(dec, 0), 1.0, 0.2) != 1 { return 68719476736; };
    if close_bits(vec_get(dec, 3), 4.0, 0.2) != 1 { return 137438953472; };
    let x: Vec<i64> = make_x2();
    let y: i64 = quant_grouped_gemv(h, x, 2, 2);
    if y == 0 { return 274877906944; };
    if vec_len(y) != 2 { return 549755813888; };
    if close_bits(vec_get(y, 0), 3.0, 0.3) != 1 { return 1099511627776; };
    if close_bits(vec_get(y, 1), 7.0, 0.3) != 1 { return 2199023255552; };
    return 0;
}

fn check_limitations_text() -> i64 {
    let s: str = quantize_limitations();
    if str_index_of(s, "FP8 now has encode, decode, GEMV, and dot") < 0 { return 4398046511104; };
    if str_index_of(s, "GROUPED signed-Q4 quantization now has") < 0 { return 8796093022208; };
    if str_index_of(s, "ERROR BOUNDS are still not documented") < 0 { return 17592186044416; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_supported_table();
    fails = fails + check_int8_decode();
    fails = fails + check_ternary_decode();
    fails = fails + check_fp8_decode_gemv_dot();
    fails = fails + check_grouped_decode_gemv();
    fails = fails + check_limitations_text();
    return fails;
}
