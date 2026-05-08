// RFC-0062 G-9 Phase 4 — positive lock-in. A wrapper that calls
// extern fns declares the `direct_ffi` effect via #[effect(direct_ffi)]
// and the framework accepts it. No FFI-G9-* diagnostic fires.

extern fn nuc_rng_int(lo: i64, hi: i64) -> i64;

#[effect(direct_ffi)]
fn ffi_wrapper(lo: i64, hi: i64) -> i64 {
    return nuc_rng_int(lo, hi);
}

#[allow_effect(direct_ffi)]
fn main() -> i32 {
    ffi_wrapper(0, 100);
    0
}
