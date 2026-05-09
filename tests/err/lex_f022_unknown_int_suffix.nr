// EXPECT: LEX-NUM-SUFFIX unrecognised suffix after integer literal
// Lane 4 audit close: F-022 (High, unknown int suffix silent drop).
// Pre-fix `1z42` lexed as int 1 + ident `z42` which then fed into the
// F-012 expression-stmt silent-drop path.
fn main() -> i32 { let x: i64 = 1z42; return 0; }
