// EXPECT: LEX-NUM-004 decimal literal ends with `_`
// Lane 4 audit close: F-018 (High, trailing underscore silent accept).
fn main() -> i32 { let x: i64 = 100_; return 0; }
