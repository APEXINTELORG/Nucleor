// EXPECT: LEX-CHAR-EMPTY empty character literal
// Lane 4 audit close: F-025 (Critical, wrong-class diagnostic).
// Pre-fix empty char `''` reported "loop labels not supported".
fn main() -> i32 { let x: i64 = ''; return 0; }
