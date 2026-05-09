// EXPECT: LEX-001 unexpected byte
// Lane 4 audit close: F-004 (High, tilde silent drop).
fn main() -> i32 { let x: i64 = ~5; return x as i32; }
