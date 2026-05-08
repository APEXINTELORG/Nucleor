// EXPECT: FFI-G5-NULL-DEREF without a dominating
// RFC-0062 G-5 Phase 4 — negative fixture. The fn calls an extern
// declared `#[may_return_null]` and uses the binding without first
// guarding with `ptr_is_null(...)`. The framework must emit
// FFI-G5-NULL-DEREF at error severity.

#[may_return_null]
extern fn nuc_rng_int(lo: i64, hi: i64) -> i64;

#[effect(direct_ffi, may_return_null)]
fn try_alloc_and_use(lo: i64, hi: i64) -> i64 {
    let p: i64 = nuc_rng_int(lo, hi);
    return p + 1;
}

#[allow_effect(direct_ffi)]
fn main() -> i32 {
    try_alloc_and_use(0, 100);
    0
}
