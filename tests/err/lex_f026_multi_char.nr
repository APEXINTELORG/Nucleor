// EXPECT: LEX-CHAR-MULTI multi-character literal
// Lane 4 audit close: F-026 (High, wrong-class diagnostic).
// Pre-fix `'ab'` reported "loop labels not supported".
fn main() -> i32 { let x: i64 = 'ab'; return 0; }
