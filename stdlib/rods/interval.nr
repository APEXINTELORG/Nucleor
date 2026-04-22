// =====================================================
// rods/interval — Interval Arithmetic (rigorous numerical bounds)
// =====================================================
// Import: import "stdlib/rods/interval.nr"
// Provides: interval construction + arithmetic with guaranteed
//   containment of the true result. The mathematical foundation for
//   computer-assisted proofs (e.g., Tucker's Lorenz attractor proof).
// =====================================================

#cfile "../runtime/interval_rt.c"

extern fn nuc_interval_pool_checkpoint() -> i64;
extern fn nuc_interval_pool_reset(checkpoint: i64);
extern fn nuc_interval_new(lo: i64, hi: i64) -> i64;
extern fn nuc_interval_point(x: i64) -> i64;
extern fn nuc_interval_lo(h: i64) -> i64;
extern fn nuc_interval_hi(h: i64) -> i64;
extern fn nuc_interval_width(h: i64) -> i64;
extern fn nuc_interval_midpoint(h: i64) -> i64;
extern fn nuc_interval_contains(h: i64, x: i64) -> i64;
extern fn nuc_interval_add(a: i64, b: i64) -> i64;
extern fn nuc_interval_sub(a: i64, b: i64) -> i64;
extern fn nuc_interval_mul(a: i64, b: i64) -> i64;
extern fn nuc_interval_div(a: i64, b: i64) -> i64;
extern fn nuc_interval_neg(h: i64) -> i64;
extern fn nuc_interval_abs(h: i64) -> i64;
extern fn nuc_interval_sqrt(h: i64) -> i64;
extern fn nuc_interval_exp(h: i64) -> i64;
extern fn nuc_interval_log(h: i64) -> i64;
extern fn nuc_interval_pow_int(h: i64, n: i64) -> i64;
extern fn nuc_interval_sin(h: i64) -> i64;
extern fn nuc_interval_cos(h: i64) -> i64;
extern fn nuc_interval_max(a: i64, b: i64) -> i64;
extern fn nuc_interval_min(a: i64, b: i64) -> i64;

fn iv_checkpoint() -> i64 { return nuc_interval_pool_checkpoint(); }
fn iv_reset(cp: i64) { nuc_interval_pool_reset(cp); }
fn iv_new(lo: i64, hi: i64) -> i64 { return nuc_interval_new(lo, hi); }
fn iv_point(x: i64) -> i64 { return nuc_interval_point(x); }
fn iv_lo(h: i64) -> i64 { return nuc_interval_lo(h); }
fn iv_hi(h: i64) -> i64 { return nuc_interval_hi(h); }
fn iv_width(h: i64) -> i64 { return nuc_interval_width(h); }
fn iv_mid(h: i64) -> i64 { return nuc_interval_midpoint(h); }
fn iv_contains(h: i64, x: i64) -> i64 { return nuc_interval_contains(h, x); }
fn iv_add(a: i64, b: i64) -> i64 { return nuc_interval_add(a, b); }
fn iv_sub(a: i64, b: i64) -> i64 { return nuc_interval_sub(a, b); }
fn iv_mul(a: i64, b: i64) -> i64 { return nuc_interval_mul(a, b); }
fn iv_div(a: i64, b: i64) -> i64 { return nuc_interval_div(a, b); }
fn iv_neg(h: i64) -> i64 { return nuc_interval_neg(h); }
fn iv_abs(h: i64) -> i64 { return nuc_interval_abs(h); }
fn iv_sqrt(h: i64) -> i64 { return nuc_interval_sqrt(h); }
fn iv_exp(h: i64) -> i64 { return nuc_interval_exp(h); }
fn iv_log(h: i64) -> i64 { return nuc_interval_log(h); }
fn iv_pow_int(h: i64, n: i64) -> i64 { return nuc_interval_pow_int(h, n); }
fn iv_sin(h: i64) -> i64 { return nuc_interval_sin(h); }
fn iv_cos(h: i64) -> i64 { return nuc_interval_cos(h); }
fn iv_max(a: i64, b: i64) -> i64 { return nuc_interval_max(a, b); }
fn iv_min(a: i64, b: i64) -> i64 { return nuc_interval_min(a, b); }
