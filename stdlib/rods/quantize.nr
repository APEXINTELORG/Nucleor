// rods/quantize — Weight + activation quantization (Q4 / int8 / ternary / FP8)
#cfile "../runtime/quantize_rt.c"

extern fn nuc_quant_q4_encode(weights: i64, n: i64) -> i64;
extern fn nuc_quant_q4_decode(h: i64) -> i64;
extern fn nuc_quant_q4_dot(a: i64, b: i64) -> i64;
extern fn nuc_quant_int8_encode(weights: i64, rows: i64, cols: i64) -> i64;
extern fn nuc_quant_int8_gemv(qw: i64, x: i64) -> i64;
extern fn nuc_quant_ternary_encode(weights: i64, n: i64) -> i64;
extern fn nuc_quant_ternary_gemv(tw: i64, x: i64, n: i64) -> i64;
extern fn nuc_quant_fp8_encode(weights: i64, n: i64, block_size: i64) -> i64;
extern fn nuc_quant_activation_magnitude(activations: i64, n_samples: i64, dim: i64) -> i64;
extern fn nuc_quant_free(h: i64);

fn quant_q4_encode(w: i64, n: i64) -> i64 { return nuc_quant_q4_encode(w, n); }
fn quant_q4_decode(h: i64) -> i64 { return nuc_quant_q4_decode(h); }
fn quant_q4_dot(a: i64, b: i64) -> i64 { return nuc_quant_q4_dot(a, b); }
fn quant_int8_encode(w: i64, rows: i64, cols: i64) -> i64 { return nuc_quant_int8_encode(w, rows, cols); }
fn quant_int8_gemv(qw: i64, x: i64) -> i64 { return nuc_quant_int8_gemv(qw, x); }
fn quant_ternary_encode(w: i64, n: i64) -> i64 { return nuc_quant_ternary_encode(w, n); }
fn quant_ternary_gemv(tw: i64, x: i64, n: i64) -> i64 { return nuc_quant_ternary_gemv(tw, x, n); }
fn quant_fp8_encode(w: i64, n: i64, block: i64) -> i64 { return nuc_quant_fp8_encode(w, n, block); }
fn quant_activation_mag(a: i64, n_samples: i64, dim: i64) -> i64 { return nuc_quant_activation_magnitude(a, n_samples, dim); }
fn quant_free(h: i64) { nuc_quant_free(h); }
