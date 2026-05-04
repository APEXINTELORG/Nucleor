// v0.7.62 negative fixture — qualified-path supertrait halts cleanly
// (was wrong-class NR020 expected `{`, got token 46).
trait Sub: super::Iterator { fn extra(self) -> i64; }
fn main() -> i64 { return 0; }
