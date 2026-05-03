// EXPECT: nucleor: tuple-struct decl not yet supported
// v0.6.53 — tuple-struct `struct P(T1, T2);` halts cleanly at parse
struct P(i64, i64);
fn main() -> i32 { return 0; }
