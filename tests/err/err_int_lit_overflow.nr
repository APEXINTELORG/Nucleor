// EXPECT: error[NUM-021] integer literal exceeds u64::MAX
// v0.4.119: decimal literals wider than u64::MAX now panic at lex
// time instead of silently wrapping through str_to_int's
// wrapping_mul/add accumulator. Pre-fix the 20-digit
// `99999999999999999999` (~5e19, beyond u64) was lexed as
// `7766279631452241919` — a meaningless garbage bit pattern that
// adopters had no signal about.
//
// u64::MAX = 18446744073709551615 (also 20 digits) still parses
// cleanly; the check compares lexicographically when the literal
// is exactly 20 digits long.

fn main() -> i32 {
    let x: i64 = 99999999999999999999;
    print_int(x);
    0
}
