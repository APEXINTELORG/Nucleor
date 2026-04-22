// 07_rust_interop.nr — Calling Rust crates from Nucleor via C ABI.
// Build: nuc build examples/07_rust_interop.nr -o rust_demo
// Run:   ./rust_demo.exe
//
// PREREQUISITE: build the rust_bridge static library first:
//   cd stdlib/rods/rust_bridge
//   cargo build --release
//
// This exposes Rust's `regex`, `base64`, hashing, and sorting crates
// to Nucleor through stdlib/rods/rust.nr — a thin Nucleor wrapper
// over the C-ABI-exported functions in rust_bridge/src/lib.rs.
//
// The same pattern works for any language that produces a static library
// (C, C++, Zig, Fortran, Go via cgo, ...): write a thin .nr wrapper with
// `extern fn` declarations and a `#link` directive.

import "stdlib/rods/rust.nr"

fn str_from_int(n: i64) -> str {
    if n == 0 { return "0"; };
    let mut s: str = "";
    let mut v: i64 = n;
    if v < 0 { v = 0 - v; };
    while v > 0 {
        let d: i64 = v - (v / 10) * 10;
        s = str_concat(str_substring("0123456789", d, d + 1), s);
        v = v / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    return s;
}

fn main() -> i64 {
    // Rust's regex crate
    let text: str = "order #1234 paid $56.78 on 2026-04-21";
    if rust_regex_match("\\d+", text) == 1 {
        print("regex matched a digit run in the text");
    };
    let n: i64 = rust_regex_count("\\d+", text);
    print(str_concat("digit runs found: ", str_from_int(n)));

    // Rust's base64
    let encoded: str = rust_base64_encode("Hello, Rust!");
    print(str_concat("base64('Hello, Rust!') = ", encoded));
    let decoded: str = rust_base64_decode(encoded);
    print(str_concat("decoded back: ", decoded));

    return 0;
}
