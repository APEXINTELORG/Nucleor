// v0.7.44 negative fixture — impl-target type with lifetime in generic
// args halts cleanly (was wrong-class NR020 expected `{`, got token 98).
struct R<'a> { v: i64 }
impl<'a> R<'a> { fn get(self) -> i64 { return self.v; } }
fn main() -> i64 { return 0; }
