// v0.7.49 negative fixture — typeless default-value param halts cleanly
// (was wrong-class NR020 expected `:`, got `=`).
fn h(x: i64, y = 5) -> i64 { return x + y; }
fn main() -> i64 { return 0; }
