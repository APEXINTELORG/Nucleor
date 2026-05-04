// EXPECT: trait-object dispatch
// Negative fixture: dyn Trait + Send / dyn Trait + Sync / dyn Trait + 'static
// all parse correctly (no NR020). The proper "vtable not yet supported" diag
// fires on the method call, not at the type-syntax level.
trait Write {
    fn write(&self, s: str) -> i64;
}

fn emit_item(w: &dyn Write + Send) -> i64 {
    return w.write("hello");
}

fn main() -> i64 {
    return 0;
}
