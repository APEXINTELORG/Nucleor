// v0.8.287 R08-D3 Phase 1 — quantization coverage disclosure.
//
// Per audit `BUILD_PLAN_R08_tensor_ml_autodiff.md` §1 R08-D3 (HIGH):
// the rod surface exposes encode + GEMV / dot for Q4, INT8, ternary
// and encode-only for FP8; FP8 decode, FP8 GEMV, INT8 decode, and
// grouped quantization are NOT shipped, and per-scheme error bounds
// are not documented. Phase 1 ships `quant_op_supported(op)` and
// `quantize_limitations()`.
//
// Phase 1 acceptance:
//   - shipped ops report supported = 1;
//   - unimplemented ops report supported = 0 (no false positives);
//   - limitations text names the 4 known gaps.
//
// Locks 7 invariants:
//   1. `q4_encode` shipped — supported = 1.
//   2. `int8_gemv` shipped — supported = 1.
//   3. `fp8_encode` shipped — supported = 1.
//   4. `fp8_gemv` NOT shipped — supported = 0.
//   5. `fp8_decode` NOT shipped — supported = 0.
//   6. `grouped_gemv` NOT shipped — supported = 0.
//   7. Limitations names "FP8" and "GROUPED" so adopters know
//      the two biggest gaps at a glance.
//
// Expected: rc=0.

import "stdlib/rods/quantize.nr"

fn check_q4_encode_shipped() -> i64 {
    if quant_op_supported("q4_encode") != 1 { return 1; };
    return 0;
}

fn check_int8_gemv_shipped() -> i64 {
    if quant_op_supported("int8_gemv") != 1 { return 2; };
    return 0;
}

fn check_fp8_encode_shipped() -> i64 {
    if quant_op_supported("fp8_encode") != 1 { return 4; };
    return 0;
}

fn check_fp8_gemv_not_shipped() -> i64 {
    if quant_op_supported("fp8_gemv") != 0 { return 8; };
    return 0;
}

fn check_fp8_decode_not_shipped() -> i64 {
    if quant_op_supported("fp8_decode") != 0 { return 16; };
    return 0;
}

fn check_grouped_gemv_not_shipped() -> i64 {
    if quant_op_supported("grouped_gemv") != 0 { return 32; };
    return 0;
}

fn check_limitations_names_gaps() -> i64 {
    let s: str = quantize_limitations();
    if str_len(s) == 0 { return 64; };
    if str_index_of(s, "FP8") < 0 { return 128; };
    if str_index_of(s, "GROUPED") < 0 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_q4_encode_shipped();
    fails = fails + check_int8_gemv_shipped();
    fails = fails + check_fp8_encode_shipped();
    fails = fails + check_fp8_gemv_not_shipped();
    fails = fails + check_fp8_decode_not_shipped();
    fails = fails + check_grouped_gemv_not_shipped();
    fails = fails + check_limitations_names_gaps();
    return fails;
}
