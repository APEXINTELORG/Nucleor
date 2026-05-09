// EXPECT: LEX-NUM-003 hex literal has no hex digits
// Lane 4 audit close: F-016 (High, 0x with no digits).
fn main() -> i32 { let x: i64 = 0x; return 0; }
