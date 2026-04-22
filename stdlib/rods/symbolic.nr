// =====================================================
// rods/symbolic — Symbolic Math (Expression Trees)
// =====================================================
// Import: import "stdlib/rods/symbolic.nr"
// Provides: build expressions from constants and named variables,
//   arithmetic and transcendentals, symbolic differentiation,
//   numerical evaluation, free.
// =====================================================

#cfile "../runtime/symbolic_rt.c"

extern fn nuc_sym_const(val: i64) -> i64;
extern fn nuc_sym_var(name: str) -> i64;
extern fn nuc_sym_add(a: i64, b: i64) -> i64;
extern fn nuc_sym_sub(a: i64, b: i64) -> i64;
extern fn nuc_sym_mul(a: i64, b: i64) -> i64;
extern fn nuc_sym_div(a: i64, b: i64) -> i64;
extern fn nuc_sym_pow(a: i64, b: i64) -> i64;
extern fn nuc_sym_sin(a: i64) -> i64;
extern fn nuc_sym_cos(a: i64) -> i64;
extern fn nuc_sym_exp(a: i64) -> i64;
extern fn nuc_sym_log(a: i64) -> i64;
extern fn nuc_sym_neg(a: i64) -> i64;
extern fn nuc_sym_sqrt(a: i64) -> i64;
extern fn nuc_sym_diff(eh: i64, var: str) -> i64;
extern fn nuc_sym_eval(eh: i64, var_name: str, val: i64) -> i64;
extern fn nuc_sym_free(eh: i64);

fn sym_const(val: i64) -> i64 { return nuc_sym_const(val); }
fn sym_var(name: str) -> i64 { return nuc_sym_var(name); }
fn sym_add(a: i64, b: i64) -> i64 { return nuc_sym_add(a, b); }
fn sym_sub(a: i64, b: i64) -> i64 { return nuc_sym_sub(a, b); }
fn sym_mul(a: i64, b: i64) -> i64 { return nuc_sym_mul(a, b); }
fn sym_div(a: i64, b: i64) -> i64 { return nuc_sym_div(a, b); }
fn sym_pow(a: i64, b: i64) -> i64 { return nuc_sym_pow(a, b); }
fn sym_sin(a: i64) -> i64 { return nuc_sym_sin(a); }
fn sym_cos(a: i64) -> i64 { return nuc_sym_cos(a); }
fn sym_exp(a: i64) -> i64 { return nuc_sym_exp(a); }
fn sym_log(a: i64) -> i64 { return nuc_sym_log(a); }
fn sym_neg(a: i64) -> i64 { return nuc_sym_neg(a); }
fn sym_sqrt(a: i64) -> i64 { return nuc_sym_sqrt(a); }
fn sym_diff(e: i64, var: str) -> i64 { return nuc_sym_diff(e, var); }
fn sym_eval(e: i64, var: str, val: i64) -> i64 { return nuc_sym_eval(e, var, val); }
fn sym_free(e: i64) { nuc_sym_free(e); }
