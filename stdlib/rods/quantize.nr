// rods/quantize — Weight + activation quantization (Q4 / int8 / ternary / FP8)
#cfile "../runtime/quantize_rt.c"

extern fn nuc_quant_q4_encode(weights: i64, n: i64) -> i64;
extern fn nuc_quant_q4_decode(h: i64) -> i64;
extern fn nuc_quant_q4_dot(a: i64, b: i64) -> i64;
extern fn nuc_quant_int8_encode(weights: i64, rows: i64, cols: i64) -> i64;
extern fn nuc_quant_int8_gemv(qw: i64, x: i64) -> i64;
extern fn nuc_quant_int8_decode(qw: i64) -> i64;
extern fn nuc_quant_ternary_encode(weights: i64, n: i64) -> i64;
extern fn nuc_quant_ternary_decode(tw: i64) -> i64;
extern fn nuc_quant_ternary_gemv(tw: i64, x: i64, rows: i64) -> i64;
extern fn nuc_quant_ternary_gemv_full(tw: i64, x: i64, rows: i64, cols: i64) -> i64;
extern fn nuc_quant_fp8_encode(weights: i64, n: i64, block_size: i64) -> i64;
extern fn nuc_quant_fp8_decode(fp8: i64) -> i64;
extern fn nuc_quant_fp8_gemv(fp8: i64, x: i64, rows: i64, cols: i64) -> i64;
extern fn nuc_quant_fp8_dot(a: i64, b: i64) -> i64;
extern fn nuc_quant_grouped_encode(weights: i64, n: i64, group_size: i64) -> i64;
extern fn nuc_quant_grouped_decode(gq: i64) -> i64;
extern fn nuc_quant_grouped_gemv(gq: i64, x: i64, rows: i64, cols: i64) -> i64;
extern fn nuc_quant_activation_magnitude(activations: i64, n_samples: i64, dim: i64) -> i64;
extern fn nuc_quant_free(h: i64);

fn quant_q4_encode(w: i64, n: i64) -> i64 { return nuc_quant_q4_encode(w, n); }
fn quant_q4_decode(h: i64) -> i64 { return nuc_quant_q4_decode(h); }
fn quant_q4_dot(a: i64, b: i64) -> i64 { return nuc_quant_q4_dot(a, b); }
fn quant_int8_encode(w: i64, rows: i64, cols: i64) -> i64 { return nuc_quant_int8_encode(w, rows, cols); }
fn quant_int8_gemv(qw: i64, x: i64) -> i64 { return nuc_quant_int8_gemv(qw, x); }
fn quant_int8_decode(qw: i64) -> i64 { return nuc_quant_int8_decode(qw); }
fn quant_ternary_encode(w: i64, n: i64) -> i64 { return nuc_quant_ternary_encode(w, n); }
fn quant_ternary_decode(tw: i64) -> i64 { return nuc_quant_ternary_decode(tw); }
fn quant_ternary_gemv(tw: i64, x: i64, rows: i64) -> i64 { return nuc_quant_ternary_gemv(tw, x, rows); }
fn quant_ternary_gemv_full(tw: i64, x: i64, rows: i64, cols: i64) -> i64 {
    return nuc_quant_ternary_gemv_full(tw, x, rows, cols);
}
fn quant_fp8_encode(w: i64, n: i64, block: i64) -> i64 { return nuc_quant_fp8_encode(w, n, block); }
fn quant_fp8_decode(fp8: i64) -> i64 { return nuc_quant_fp8_decode(fp8); }
fn quant_fp8_gemv(fp8: i64, x: i64, rows: i64, cols: i64) -> i64 { return nuc_quant_fp8_gemv(fp8, x, rows, cols); }
fn quant_fp8_dot(a: i64, b: i64) -> i64 { return nuc_quant_fp8_dot(a, b); }
fn quant_grouped_encode(w: i64, n: i64, group_size: i64) -> i64 { return nuc_quant_grouped_encode(w, n, group_size); }
fn quant_grouped_decode(gq: i64) -> i64 { return nuc_quant_grouped_decode(gq); }
fn quant_grouped_gemv(gq: i64, x: i64, rows: i64, cols: i64) -> i64 { return nuc_quant_grouped_gemv(gq, x, rows, cols); }
fn quant_activation_mag(a: i64, n_samples: i64, dim: i64) -> i64 { return nuc_quant_activation_magnitude(a, n_samples, dim); }
fn quant_free(h: i64) { nuc_quant_free(h); }

// === R08-D3 Phase 1 (v0.8.287) — quantization coverage disclosure ===
//
// Per audit `BUILD_PLAN_R08_tensor_ml_autodiff.md` §1 R08-D3 (HIGH):
// the rod shipped encode + GEMV / dot for Q4, INT8, ternary; encode-only
// for FP8 (no FP8 GEMV, no FP8 decode); no grouped quantization at
// all; no INT8 decode; documented error bounds absent.
//
// Helper1 v0859 closes the missing decode/inference surface for FP8,
// INT8, ternary, and grouped signed-Q4 quantization.
//
// Phase 1 (audit's rollback path: expose unsupported diagnostics for
// unimplemented quant modes) ships `quant_op_supported(op)` returning
// 1 if the named op is shipped today, 0 if Phase 2 work, plus
// `quantize_limitations()` text helper. Phase 2 wires the missing
// surfaces (FP8 GEMV / decode, INT8 decode, grouped quant, error
// bounds doc).

// Returns 1 if the named op is shipped, 0 otherwise.
// Adopters call this before designing a pipeline around an op.
fn quant_op_supported(op: str) -> i64 {
    if str_eq(op, "q4_encode") == 1 { return 1; };
    if str_eq(op, "q4_decode") == 1 { return 1; };
    if str_eq(op, "q4_dot") == 1 { return 1; };
    if str_eq(op, "int8_encode") == 1 { return 1; };
    if str_eq(op, "int8_gemv") == 1 { return 1; };
    if str_eq(op, "int8_decode") == 1 { return 1; };
    if str_eq(op, "ternary_encode") == 1 { return 1; };
    if str_eq(op, "ternary_decode") == 1 { return 1; };
    if str_eq(op, "ternary_gemv") == 1 { return 1; };
    if str_eq(op, "ternary_gemv_full") == 1 { return 1; };
    if str_eq(op, "fp8_encode") == 1 { return 1; };
    if str_eq(op, "fp8_decode") == 1 { return 1; };
    if str_eq(op, "fp8_gemv") == 1 { return 1; };
    if str_eq(op, "fp8_dot") == 1 { return 1; };
    if str_eq(op, "grouped_encode") == 1 { return 1; };
    if str_eq(op, "grouped_decode") == 1 { return 1; };
    if str_eq(op, "grouped_gemv") == 1 { return 1; };
    // Phase 2 work — explicitly unsupported today:
    if str_eq(op, "fp8_true_e4m3_bits") == 1 { return 0; };
    if str_eq(op, "quant_error_bounds") == 1 { return 0; };
    return 0;
}

fn quantize_limitations() -> str {
    return "Quantization rod limitations (ML-6/ML-7/ML-9, audit R08-D3 v0.8.287/helper1 v0859): (1) FP8 now has encode, decode, GEMV, and dot over the existing simplified signed-byte scaled representation; true IEEE-style E4M3 bit encoding remains future work. (2) INT8 now has encode, GEMV, and decode for inspection/debugging. (3) Ternary now has encode, decode, 3-arg GEMV, and explicit 4-arg GEMV. (4) GROUPED signed-Q4 quantization now has grouped_encode / grouped_decode / grouped_gemv with per-group scales for GPTQ-style row-major weight blocks. (5) ERROR BOUNDS are still not documented per scheme; adopters must measure round-trip error before relying on a tolerance. Query quant_op_supported(op_name) for per-op truth.";
}
