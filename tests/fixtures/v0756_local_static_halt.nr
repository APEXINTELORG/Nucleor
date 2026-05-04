// v0.7.56 negative fixture — local `static` inside fn body halts cleanly
// (was wrong-class NR020 token kind 42).
fn h() -> i64 { static N: i64 = 5; return N; }
fn main() -> i64 { return 0; }
