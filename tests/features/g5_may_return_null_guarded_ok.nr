// RFC-0062 G-5 Phase 4 — positive lock-in. A fn calls an extern
// declared `#[may_return_null]` and binds the result, then guards
// any subsequent use behind a `ptr_is_null(...)` check on the same
// path. The framework's G-5 deref-after-extern-call dataflow check
// recognises the guard and emits no FFI-G5-NULL-DEREF.

#[may_return_null]
extern fn nuc_rng_int(lo: i64, hi: i64) -> i64;

fn ptr_is_null(p: i64) -> i64 {
    if p == 0 { return 1; };
    return 0;
}

#[effect(direct_ffi, may_return_null)]
fn try_alloc_and_use(lo: i64, hi: i64) -> i64 {
    let p: i64 = nuc_rng_int(lo, hi);
    if ptr_is_null(p) == 1 {
        return 0 - 1;
    };
    return p + 1;
}

#[allow_effect(direct_ffi)]
fn main() -> i32 {
    try_alloc_and_use(0, 100);
    0
}
