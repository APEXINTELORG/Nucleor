// EXPECT: error[LEX-STRING-EOF]
// Unterminated string literal reaches physical EOF.
fn main() -> i64 {
    let s: str = "unterminated