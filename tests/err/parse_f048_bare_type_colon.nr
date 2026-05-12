// EXPECT: PARSE-TYPE-001 expected a type, found `;`
// Regression gate Layer 1 F-048: a bare type annotation colon must halt
// at parse-time instead of falling through to a binding/type checker
// diagnostic.
fn main() -> i32 { let x: ; return 0; }
