// R06 Phase 3a - rust_bridge deterministic hash plus owned string cleanup.
//
// The bridge already exposes rust_hash_string_fnv1a, a deterministic
// primitive-return helper. This fixture keeps that behavior under the
// opt-in ownership harness and pairs every Rust-owned returned string with
// rust_free_str.
//
// Expected: rc=0.

import "stdlib/rods/rust.nr"

fn check_fnv1a_determinism() -> i64 {
    let h1: i64 = rust_hash_string_fnv1a("hello");
    let h2: i64 = rust_hash_string_fnv1a("hello");
    if h1 != h2 { return 1; };

    let h3: i64 = rust_hash_string_fnv1a("world");
    if h1 == h3 { return 2; };
    return 0;
}

fn check_fnv1a_empty_pinned() -> i64 {
    // FNV-1a 64-bit offset_basis = 0xcbf29ce484222325.
    // Reinterpreted as signed i64: -3750763034362895579.
    let h: i64 = rust_hash_string_fnv1a("");
    if h != 0 - 3750763034362895579 { return 4; };
    return 0;
}

fn check_owned_string_cleanup() -> i64 {
    let upper: str = rust_to_uppercase("hash-owned");
    if str_eq(upper, "HASH-OWNED") != 1 {
        rust_free_str(upper);
        return 8;
    };
    rust_free_str(upper);

    let encoded: str = rust_base64_encode("hash");
    if str_eq(encoded, "aGFzaA==") != 1 {
        rust_free_str(encoded);
        return 16;
    };
    rust_free_str(encoded);
    return 0;
}

fn check_old_api_callable() -> i64 {
    let h: i64 = rust_hash_string("hello");
    if h == h { return 0; };
    return 32;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_fnv1a_determinism();
    fails = fails + check_fnv1a_empty_pinned();
    fails = fails + check_owned_string_cleanup();
    fails = fails + check_old_api_callable();
    return fails;
}
