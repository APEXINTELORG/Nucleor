// EXPECT: nucleor: byte string `b"..."` not yet supported
// v0.6.58 — byte string literal halts cleanly at lex (was wrong-class TYP-005)
fn main() -> i32 {
    let bs = b"hello";
    return 0;
}
