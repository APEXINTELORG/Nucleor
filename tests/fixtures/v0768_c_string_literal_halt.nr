// v0.7.68 negative fixture — Rust C-string literal `c"..."` halt.
// Promoted from probe finding 2026-05-03 (raw/byte/C-string family).
// Pre-fix the `c` lexed as an ident and the parser called fn `c` on
// the trailing string literal, producing the wrong-class TYP-005.
// Now halts at lex with workaround pointer (use `"...\0"` at FFI).
fn main() -> i64 {
    let s: str = c"hello";
    return 0;
}
