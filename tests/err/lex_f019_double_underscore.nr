// EXPECT: LEX-NUM-002 consecutive `__` in decimal literal
// Lane 4 audit close: F-019 (High, double underscore silent accept).
fn main() -> i32 { let x: i64 = 1__2; return 0; }
