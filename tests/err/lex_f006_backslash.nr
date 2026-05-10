// EXPECT: LEX-001 unexpected byte
// Audit close: F-006 (High, bare backslash silently dropped).
fn main() -> i32 { let x: i64 = \5; return x as i32; }
