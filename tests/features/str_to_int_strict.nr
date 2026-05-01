// stdlib runtime — `str_to_int_strict` opt-in strict variant
// (v0.5.12). Probe-agent finding
// 2026-05-01-str-to-int-silent-zero-on-invalid.
//
// `str_to_int` returns 0 silently on parse failure (NULL / empty
// / "not a number" / "123abc" silent prefix-parse) — adopters can't
// distinguish parse-failed-to-zero from parse-succeeded-to-zero.
// v0.5.12 ships `str_to_int_strict` mirroring v0.4.279's
// `str_char_at_strict` opt-in template: lenient default stays
// (perf path / lex-time), strict variant panics on any failure
// shape. Adopters port from Rust's `i64::from_str(s).unwrap()` by
// switching to this helper.
//
// EXPECT: build success, runtime exit 0, prints values + "OK".

fn main() -> i32 {
    // Valid inputs — strict succeeds.
    let a: i64 = str_to_int_strict("123");
    if a != 123 { print("FAIL 123"); return 1; };
    print_int(a as i32);

    let b: i64 = str_to_int_strict("0");
    if b != 0 { print("FAIL 0"); return 1; };
    print_int(b as i32);

    let c: i64 = str_to_int_strict("-42");
    if c != 0 - 42 { print("FAIL -42"); return 1; };
    print_int(c as i32);

    // Trailing whitespace tolerated; only non-whitespace garbage panics.
    let d: i64 = str_to_int_strict("  17  ");
    if d != 17 { print("FAIL 17 with whitespace"); return 1; };
    print_int(d as i32);

    print("OK str_to_int_strict");
    0
}
