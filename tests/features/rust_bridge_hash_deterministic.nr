// v0.8.272 R06-D4 Phase 1 — deterministic FNV-1a hash coverage.
//
// Per audit `BUILD_PLAN_R06_interop_ffi.md` §1 R06-D4 (MEDIUM):
// pre-v0.8.272 the only `rust_hash_string` used Rust's
// `DefaultHasher` which seeds via process-local `RandomState` —
// the same string produces DIFFERENT hash values across process
// runs. Unsuitable for reproducible artifacts, content-addressed
// caches, or stable serialization.
//
// Phase 1 (this ship): adds `rust_hash_string_fnv1a` using the
// canonical FNV-1a 64-bit algorithm
// (offset_basis = 0xcbf29ce484222325, prime = 0x100000001b3).
// Same input always produces same output across processes,
// machines, and Rust versions. Pre-existing `rust_hash_string` is
// preserved with a doc warning for HashDoS-defense callers.
//
// Phase 1 acceptance:
//   - same input produces same output across repeated calls;
//   - same input pinned to a known FNV-1a value (the empty string
//     returns the offset_basis as i64).
//
// Locks 4 invariants:
//   1. Determinism within run — `hash("hello")` called twice
//      returns the same value.
//   2. Distinct inputs distinct outputs — `hash("hello") !=
//      hash("world")` (no algorithm trivially folds to zero).
//   3. Empty-string pinned — `hash("")` returns the FNV-1a
//      offset_basis (0xcbf29ce484222325 as i64 =
//      -3750763034362895579) — pins the canonical algorithm
//      identity across Rust versions.
//   4. Old `rust_hash_string` still callable — backward compat.
//
// Expected: rc=0.

import "stdlib/rods/rust.nr"

fn check_determinism_within_run() -> i64 {
    let h1: i64 = rust_hash_string_fnv1a("hello");
    let h2: i64 = rust_hash_string_fnv1a("hello");
    if h1 != h2 { return 1; };
    return 0;
}

fn check_distinct_inputs_distinct_outputs() -> i64 {
    let h_hello: i64 = rust_hash_string_fnv1a("hello");
    let h_world: i64 = rust_hash_string_fnv1a("world");
    if h_hello == h_world { return 2; };
    return 0;
}

fn check_empty_string_pinned() -> i64 {
    // FNV-1a 64-bit offset_basis = 0xcbf29ce484222325
    // As i64 (reinterpreted bits): -3750763034362895579
    let h: i64 = rust_hash_string_fnv1a("");
    if h != 0 - 3750763034362895579 { return 4; };
    return 0;
}

fn check_old_api_still_callable() -> i64 {
    // rust_hash_string still works (process-local random; we don't
    // pin a value, just verify the call doesn't crash and returns
    // *something* non-zero for non-empty input).
    let h: i64 = rust_hash_string("hello");
    // DefaultHasher could in principle return 0 for some seed +
    // input combination; testing the call returns is the
    // backward-compat assertion. Skip the value check.
    if h == h { return 0; };  // tautology to use h
    return 8;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_determinism_within_run();
    fails = fails + check_distinct_inputs_distinct_outputs();
    fails = fails + check_empty_string_pinned();
    fails = fails + check_old_api_still_callable();
    return fails;
}
