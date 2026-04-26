// t410_str_to_int_user.nr — v0.3.136 regression fixture.
//
// Pins `str_to_int` as a user-callable runtime helper. The s1
// compiler defines its own internal `str_to_int` fn (line 32 of
// nucleor_s1_compiler.nr) for lex-time digit parsing. Pre-v0.3.136,
// adopters writing `str_to_int("123")` in their .nr code hit
// `clang: undefined value '@str_to_int'` because no runtime helper
// was registered — the symbol existed in the compiler self-host
// source only.
//
// Symmetric to `__nucleor_str_to_f64`. Returns 0 on parse failure
// (matches str_to_f64's failure mode).
//
// Returns 57 = 12345 mod 256, proving str_to_int parses the
// decimal text and returns the i64 value.

fn main() -> i64 {
    let n: i64 = str_to_int("12345");
    return n;
}
