// v0.7.7 (defensive halt): C/Java-idiom `x++` / `x--` post-
// increment/decrement operators don't exist in Rust (or Nucleor).
// Pre-fix surfaced as wrong-class `NR020: parse_primary cannot
// start expression at token kind 20` (the second `+` after `x+`)
// because the `+` after the primary parses as a binop, then
// parse_primary fails on the second `+`. Now halts cleanly with
// `x = x + 1` workaround pointer. Negative fixture (compile rejects).
fn main() -> i32 {
    let mut x: i64 = 5;
    x++;    // ← halts: post-increment not supported
    return 0;
}
