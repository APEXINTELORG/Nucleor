// v0.7.52 negative fixture — module-scope forward fn declaration
// halts cleanly (was wrong-class NR020 expected `{`, got `;`).
fn helper() -> i64;
fn main() -> i64 { return 0; }
