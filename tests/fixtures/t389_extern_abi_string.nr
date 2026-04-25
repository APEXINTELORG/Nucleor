// t389_extern_abi_string.nr — v0.3.112 regression fixture.
//
// Pins `extern "C" fn name(...)` declarations. Pre-v0.3.112, the
// parser only recognized bare `extern fn`, so the canonical Rust
// FFI form `extern "C" fn abs(x: i64) -> i64;` cascaded into 4+
// parse errors. Adopters reaching for FFI to libc functions
// (abs, atoi, fopen, ...) hit this on the first declaration.
//
// The ABI string is accepted and discarded — Nucleor's only ABI
// today is the C calling convention used by all extern decls,
// so the explicit marker is informational. Skipping the literal
// string lets the existing parse_extern_fn handle the `fn name(...)`
// part unchanged.
//
// Returns 42 = abs(-42), proving the linked C runtime function
// is reachable through the new declaration form.

extern "C" fn abs(x: i64) -> i64;

fn main() -> i64 {
    return abs(0 - 42);
}
