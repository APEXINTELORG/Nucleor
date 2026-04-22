// =====================================================
// rods/bigint — Arbitrary-precision integers
// =====================================================
// Import: import "stdlib/rods/bigint.nr"
// Provides: construction from i64/str, arithmetic, modular exp.
// =====================================================

#cfile "../runtime/bigint_rt.c"

extern fn nuc_bi_from_str(s: str) -> i64;
extern fn nuc_bi_from_i64(v: i64) -> i64;
extern fn nuc_bi_cmp(a: i64, b: i64) -> i64;
extern fn nuc_bi_add(a: i64, b: i64) -> i64;
extern fn nuc_bi_sub(a: i64, b: i64) -> i64;
extern fn nuc_bi_mul(a: i64, b: i64) -> i64;
extern fn nuc_bi_div(a: i64, b: i64) -> i64;
extern fn nuc_bi_mod(a: i64, b: i64) -> i64;
extern fn nuc_bi_powmod(base: i64, exp: i64, mod_h: i64) -> i64;

fn bi_from_str(s: str) -> i64 { return nuc_bi_from_str(s); }
fn bi_from_int(v: i64) -> i64 { return nuc_bi_from_i64(v); }
fn bi_cmp(a: i64, b: i64) -> i64 { return nuc_bi_cmp(a, b); }
fn bi_add(a: i64, b: i64) -> i64 { return nuc_bi_add(a, b); }
fn bi_sub(a: i64, b: i64) -> i64 { return nuc_bi_sub(a, b); }
fn bi_mul(a: i64, b: i64) -> i64 { return nuc_bi_mul(a, b); }
fn bi_div(a: i64, b: i64) -> i64 { return nuc_bi_div(a, b); }
fn bi_mod(a: i64, b: i64) -> i64 { return nuc_bi_mod(a, b); }
fn bi_powmod(base: i64, exp: i64, mod_h: i64) -> i64 { return nuc_bi_powmod(base, exp, mod_h); }
