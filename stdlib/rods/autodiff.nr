// =====================================================
// rods/autodiff — Reverse-Mode Automatic Differentiation
// =====================================================
// Import: import "stdlib/rods/autodiff.nr"
// Provides: var / const nodes, arithmetic, transcendentals,
//   abs, tanh, value + gradient extraction, tape reset + checkpoint.
// =====================================================

#cfile "../runtime/autodiff_rt.c"

extern fn nuc_ad_var(val: i64) -> i64;
extern fn nuc_ad_const(val: i64) -> i64;
extern fn nuc_ad_add(a: i64, b: i64) -> i64;
extern fn nuc_ad_sub(a: i64, b: i64) -> i64;
extern fn nuc_ad_mul(a: i64, b: i64) -> i64;
extern fn nuc_ad_div(a: i64, b: i64) -> i64;
extern fn nuc_ad_neg(a: i64) -> i64;
extern fn nuc_ad_sin(a: i64) -> i64;
extern fn nuc_ad_cos(a: i64) -> i64;
extern fn nuc_ad_exp(a: i64) -> i64;
extern fn nuc_ad_log(a: i64) -> i64;
extern fn nuc_ad_sqrt(a: i64) -> i64;
extern fn nuc_ad_pow(a: i64, n: i64) -> i64;
extern fn nuc_ad_abs(a: i64) -> i64;
extern fn nuc_ad_tanh(a: i64) -> i64;
extern fn nuc_ad_value(h: i64) -> i64;
extern fn nuc_ad_grad(h: i64, var: i64) -> i64;
extern fn nuc_ad_reset();
extern fn nuc_ad_checkpoint() -> i64;
extern fn nuc_ad_restore(checkpoint: i64);

fn ad_var(val: i64) -> i64 { return nuc_ad_var(val); }
fn ad_const(val: i64) -> i64 { return nuc_ad_const(val); }
fn ad_add(a: i64, b: i64) -> i64 { return nuc_ad_add(a, b); }
fn ad_sub(a: i64, b: i64) -> i64 { return nuc_ad_sub(a, b); }
fn ad_mul(a: i64, b: i64) -> i64 { return nuc_ad_mul(a, b); }
fn ad_div(a: i64, b: i64) -> i64 { return nuc_ad_div(a, b); }
fn ad_neg(a: i64) -> i64 { return nuc_ad_neg(a); }
fn ad_sin(a: i64) -> i64 { return nuc_ad_sin(a); }
fn ad_cos(a: i64) -> i64 { return nuc_ad_cos(a); }
fn ad_exp(a: i64) -> i64 { return nuc_ad_exp(a); }
fn ad_log(a: i64) -> i64 { return nuc_ad_log(a); }
fn ad_sqrt(a: i64) -> i64 { return nuc_ad_sqrt(a); }
fn ad_pow(a: i64, n: i64) -> i64 { return nuc_ad_pow(a, n); }
fn ad_abs(a: i64) -> i64 { return nuc_ad_abs(a); }
fn ad_tanh(a: i64) -> i64 { return nuc_ad_tanh(a); }
fn ad_value(h: i64) -> i64 { return nuc_ad_value(h); }
fn ad_grad(h: i64, var: i64) -> i64 { return nuc_ad_grad(h, var); }
fn ad_reset() { nuc_ad_reset(); }
fn ad_checkpoint() -> i64 { return nuc_ad_checkpoint(); }
fn ad_restore(cp: i64) { nuc_ad_restore(cp); }
