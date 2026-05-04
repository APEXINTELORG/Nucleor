// v0.7.57 negative fixture — `where`-clause on enum decl halts cleanly
// (was wrong-class NR020 expected `{`, got identifier).
enum E<T> where T: Copy { A(T) }
fn main() -> i64 { return 0; }
