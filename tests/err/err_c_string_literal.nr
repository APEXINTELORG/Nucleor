// EXPECT: nucleor: C string `c"..."` not yet supported
// v0.7.18 - C string literal halts cleanly at lex (was wrong-class TYP-005)
fn main() -> i32 {
    let s = c"hello";
    return 0;
}
