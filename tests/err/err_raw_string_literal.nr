// EXPECT: nucleor: raw string `r"..."` not yet supported
// v0.6.58 — raw string literal halts cleanly at lex (was wrong-class TYP-005)
fn main() -> i32 {
    let s: str = r"raw string content";
    return 0;
}
