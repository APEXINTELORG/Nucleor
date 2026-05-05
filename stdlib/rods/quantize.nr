// rods/quantize — Weight + activation quantization (Q4 / int8 / ternary / FP8)
#cfile "../runtime/quantize_rt.c"

extern fn nuc_quant_q4_encode(weights: i64, n: i64) -> i64;
extern fn nuc_quant_q4_decode(h: i64) -> i64;
extern fn nuc_quant_q4_dot(a: i64, b: i64) -> i64;
extern fn nuc_quant_int8_encode(weights: i64, rows: i64, cols: i64) -> i64;
extern fn nuc_quant_int8_gemv(qw: i64, x: i64) -> i64;
extern fn nuc_quant_ternary_encode(weights: i64, n: i64) -> i64;
extern fn nuc_quant_ternary_gemv(tw: i64, x: i64, rows: i64) -> i64;
extern fn nuc_quant_ternary_gemv_full(tw: i64, x: i64, rows: i64, cols: i64) -> i64;
extern fn nuc_quant_fp8_encode(weights: i64, n: i64, block_size: i64) -> i64;
extern fn nuc_quant_activation_magnitude(activations: i64, n_samples: i64, dim: i64) -> i64;
extern fn nuc_quant_free(h: i64);

fn quant_q4_encode(w: i64, n: i64) -> i64 { return nuc_quant_q4_encode(w, n); }
fn quant_q4_decode(h: i64) -> i64 { return nuc_quant_q4_decode(h); }
fn quant_q4_dot(a: i64, b: i64) -> i64 { return nuc_quant_q4_dot(a, b); }
fn quant_int8_encode(w: i64, rows: i64, cols: i64) -> i64 { return nuc_quant_int8_encode(w, rows, cols); }
fn quant_int8_gemv(qw: i64, x: i64) -> i64 { return nuc_quant_int8_gemv(qw, x); }
fn quant_ternary_encode(w: i64, n: i64) -> i64 { return nuc_quant_ternary_encode(w, n); }
fn quant_ternary_gemv(tw: i64, x: i64, rows: i64) -> i64 { return nuc_quant_ternary_gemv(tw, x, rows); }
fn quant_ternary_gemv_full(tw: i64, x: i64, rows: i64, cols: i64) -> i64 {
    return nuc_quant_ternary_gemv_full(tw, x, rows, cols);
}
fn quant_fp8_encode(w: i64, n: i64, block: i64) -> i64 { return nuc_quant_fp8_encode(w, n, block); }
fn quant_activation_mag(a: i64, n_samples: i64, dim: i64) -> i64 { return nuc_quant_activation_magnitude(a, n_samples, dim); }
fn quant_free(h: i64) { nuc_quant_free(h); }

// === R08-D3 Phase 1 (v0.8.287) — quantization coverage disclosure ===
//
// Per audit `BUILD_PLAN_R08_tensor_ml_autodiff.md` §1 R08-D3 (HIGH):
// the rod ships encode + GEMV / dot for Q4, INT8, ternary; encode-only
// for FP8 (no FP8 GEMV, no FP8 decode); no grouped quantization at
// all; no INT8 decode; documented error bounds absent.
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
    if str_eq(op, "ternary_encode") == 1 { return 1; };
    if str_eq(op, "ternary_gemv") == 1 { return 1; };
    if str_eq(op, "ternary_gemv_full") == 1 { return 1; };
    if str_eq(op, "fp8_encode") == 1 { return 1; };
    // Phase 2 work — explicitly unsupported today:
    if str_eq(op, "fp8_decode") == 1 { return 0; };
    if str_eq(op, "fp8_gemv") == 1 { return 0; };
    if str_eq(op, "int8_decode") == 1 { return 0; };
    if str_eq(op, "grouped_encode") == 1 { return 0; };
    if str_eq(op, "grouped_decode") == 1 { return 0; };
    if str_eq(op, "grouped_gemv") == 1 { return 0; };
    return 0;
}

fn quantize_limitations() -> str {
    return "Quantization rod limitations (ML-9, audit R08-D3 v0.8.287): (1) FP8: encode-only — no fp8_decode and no fp8_gemv; adopters cannot dot products against an FP8-quantized weight matrix without round-tripping back to f32 manually. (2) INT8: encode + gemv shipped, but no int8_decode for inspection / debugging. (3) GROUPED quantization: not shipped — no grouped_encode / grouped_decode / grouped_gemv; per-channel and per-block schemes used in modern model-compression pipelines (e.g. AWQ, GPTQ groupwise) are NOT available through this rod yet. (4) ERROR BOUNDS: not documented per scheme — adopters must measure round-trip error themselves before relying on a tolerance. Query quant_op_supported(op_name) for per-op truth. Phase 2 ships the four gaps above with deterministic small fixtures + documented tolerances per RFC.";
}
