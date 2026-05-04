// v0.7.59 negative fixture — local fn decl inside fn body halts cleanly
// (was wrong-class NR020 token kind 10).
fn outer() -> i64 {
    fn inner() -> i64 { return 42; }
    return inner();
}
fn main() -> i64 { return 0; }
