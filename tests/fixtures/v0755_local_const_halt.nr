// v0.7.55 negative fixture — local `const` inside fn body halts cleanly
// (was wrong-class NR020 token kind 73).
fn h() -> i64 { const N: i64 = 5; return N; }
fn main() -> i64 { return 0; }
