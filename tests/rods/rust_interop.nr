// rust_interop.nr — Rust regex + base64 via rust_bridge
// Requires: cd stdlib/rods/rust_bridge && cargo build --release
import "stdlib/rods/rust.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    if rust_regex_match("[0-9]+", "phone: 5551234") != 1 {
        print("FAIL rust: regex_match");
        fail = fail + 1;
    };

    let n: i64 = rust_regex_count("[0-9]+", "1, 2, 3 and 4");
    if n != 4 {
        print("FAIL rust: regex_count expected 4");
        fail = fail + 1;
    };

    let enc: str = rust_base64_encode("nucleor");
    if str_eq(enc, "bnVjbGVvcg==") != 1 {
        print(str_concat("FAIL rust: base64 encode = ", enc));
        fail = fail + 1;
    };
    let dec: str = rust_base64_decode(enc);
    if str_eq(dec, "nucleor") != 1 {
        print(str_concat("FAIL rust: base64 decode = ", dec));
        fail = fail + 1;
    };

    if fail == 0 { print("OK rust_interop"); return 0; };
    return 1;
}
