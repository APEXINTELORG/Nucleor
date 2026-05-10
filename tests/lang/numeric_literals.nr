// numeric_literals.nr — RFC-0015 phase 1 lexer support
// Underscores as digit separators + integer/float type suffixes.
// All values still treated as i64 / f64 internally until later RFC-0015
// phases land — the goal here is that the LEXER accepts the syntax.

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Underscore separators in integers
    let a: i64 = 1_000_000;
    if a != 1000000 { fail = fail + 1; print("FAIL: underscore int\n"); };

    let b: i64 = 1_2_3_4_5;
    if b != 12345 { fail = fail + 1; print("FAIL: dense underscore int\n"); };

    // Integer suffixes (lexer accepts; payload still i64)
    let d: i64 = 100i32;
    if d != 100 { fail = fail + 1; print("FAIL: i32 suffix\n"); };

    let e: i64 = 255u8;
    if e != 255 { fail = fail + 1; print("FAIL: u8 suffix\n"); };

    let f: i64 = 1_000_000_000i64;
    if f != 1000000000 { fail = fail + 1; print("FAIL: i64 suffix with underscores\n"); };

    let g: usize = 42usize;
    if g != 42usize { fail = fail + 1; print("FAIL: usize suffix\n"); };

    if fail == 0 { print("OK numeric_literals\n"); return 0; };
    return 1;
}
