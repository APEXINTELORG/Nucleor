// v0643_unary_neg_min_panics.nr — v0.6.43 regression fixture.
//
// Closes probe finding 2026-05-01-unary-neg-runtime-overflow-not-
// checked. Pre-fix `neg(-i64::MIN)` silently wrapped to i64::MIN —
// asymmetric with `+`/`*` which already PANIC by default via
// NUCLEOR_INT_STRICT_INTRIN=1. v0.6.43 makes unary-neg consult
// the same env var with the same default, so `-x` for i64 routes
// through panic_neg by default.
//
// Build + run; expect non-zero exit with PANIC line.

fn neg(x: i64) -> i64 { -x }

fn main() -> i32 {
    let r: i64 = neg(-9223372036854775808);
    print_int(r as i32);
    0
}
