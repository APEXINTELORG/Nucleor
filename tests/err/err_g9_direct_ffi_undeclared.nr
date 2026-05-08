// EXPECT: FFI-G9-MISSING-ALLOW-DIRECT-FFI calls extern fn
// RFC-0062 G-9 Phase 4 — negative fixture. The fn calls an extern
// fn but carries no #[effect(direct_ffi)] declaration and no
// #[allow_effect(direct_ffi)] silencer. The framework must emit
// FFI-G9-MISSING-ALLOW-DIRECT-FFI at error severity.

extern fn nuc_rng_int(lo: i64, hi: i64) -> i64;

#[allow_effect(direct_ffi)]
fn dummy_keep_gate_open(lo: i64, hi: i64) -> i64 {
    return nuc_rng_int(lo, hi);
}

fn ffi_unguarded(lo: i64, hi: i64) -> i64 {
    return nuc_rng_int(lo, hi);
}

#[allow_effect(direct_ffi)]
fn main() -> i32 {
    ffi_unguarded(0, 100);
    dummy_keep_gate_open(0, 100);
    0
}
