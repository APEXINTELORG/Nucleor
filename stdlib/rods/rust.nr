// =====================================================
// rods/rust — Rust interop via C ABI
// =====================================================
// Import: import "stdlib/rods/rust.nr"
// Requires: stdlib/rods/rust_bridge compiled (cargo build --release)
// Link: #link "nucleor_rust_bridge" + Windows system libs
// Provides: rust_regex_match, rust_regex_find, rust_regex_count,
//   rust_regex_replace, rust_hash, rust_sort_ints, rust_sort_strings,
//   rust_uppercase, rust_base64_encode, rust_base64_decode
// =====================================================

#libpath "rust_bridge/target/release"
#link "nucleor_rust_bridge"
#link "ws2_32"
#link "userenv"
#link "ntdll"
#link "bcrypt"

extern fn rust_regex_is_match(pattern: str, text: str) -> i64;
extern fn rust_regex_find(pattern: str, text: str) -> str;
extern fn rust_regex_count(pattern: str, text: str) -> i64;
extern fn rust_regex_replace_all(pattern: str, text: str, replacement: str) -> str;
extern fn rust_hash_string(s: str) -> i64;
// R06-D4 Phase 1 (v0.8.272) — deterministic FNV-1a 64-bit string
// hash. Use for reproducible artifacts; rust_hash_string is per-
// process randomized (HashDoS defense, NOT reproducible).
extern fn rust_hash_string_fnv1a(s: str) -> i64;
extern fn rust_sort_ints(csv: str) -> str;
extern fn rust_sort_strings(csv: str) -> str;
extern fn rust_to_uppercase(s: str) -> str;
extern fn rust_base64_encode(s: str) -> str;
extern fn rust_base64_decode(s: str) -> str;
// R06-D1 Phase 1 (v0.8.270) — reclamation hook for the 7 string-
// returning functions above. Caller MUST pass the exact pointer
// returned to reclaim the allocation. Audit cite:
// stdlib/rods/rust_bridge/src/lib.rs FFI-1 — every into_raw() now
// has a from_raw() reclaim path.
extern fn rust_free_str(s: str);

// Nucleor-friendly wrappers

fn rust_regex_match(pattern: str, text: str) -> i64 {
    return rust_regex_is_match(pattern, text);
}

fn rust_regex_find_first(pattern: str, text: str) -> str {
    return rust_regex_find(pattern, text);
}

fn rust_regex_replace(pattern: str, text: str, replacement: str) -> str {
    return rust_regex_replace_all(pattern, text, replacement);
}

fn rust_hash(s: str) -> i64 {
    return rust_hash_string(s);
}

fn rust_uppercase(s: str) -> str {
    return rust_to_uppercase(s);
}
