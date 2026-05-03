// EXPECT: NUM-021 decimal literal `9223372036854775808` exceeds i64::MAX
// v0.6.68 — match-arm overflow halts cleanly at lex (was silent dead arm)
fn main() -> i32 {
    let x: i64 = 9223372036854775807;
    let r: i64 = match x {
        9223372036854775808 => 1,
        _ => 0,
    };
    return r as i32;
}
