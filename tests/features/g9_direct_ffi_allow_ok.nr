// RFC-0062 G-9 Phase 4 — positive lock-in. A wrapper that calls
// an extern fn opts out of the direct_ffi declaration via
// #[allow_effect(direct_ffi)] (intentional, audited surface). The
// framework recognises the silencer and emits no FFI-G9-* diagnostic.

extern fn nuc_rng_int(lo: i64, hi: i64) -> i64;

#[allow_effect(direct_ffi)]
fn ffi_wrapper(lo: i64, hi: i64) -> i64 {
    return nuc_rng_int(lo, hi);
}

#[allow_effect(direct_ffi)]
fn main() -> i32 {
    ffi_wrapper(0, 100);
    0
}
