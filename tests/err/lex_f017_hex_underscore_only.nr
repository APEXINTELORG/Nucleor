// EXPECT: LEX-NUM-001 hex literal starts with `_`
// Lane 4 audit close: F-017 (High, 0x_ underscore-only digit body).
fn main() -> i32 { let x: i64 = 0x_; return 0; }
