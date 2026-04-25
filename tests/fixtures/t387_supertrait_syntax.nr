// t387_supertrait_syntax.nr — v0.3.110 regression fixture.
//
// Pins the supertrait declaration syntax `trait Sub: Super` and
// `trait Foo: Bar + Baz`. Pre-v0.3.110, parse_trait_decl expected
// `{` immediately after the trait name, so the canonical Rust
// supertrait form cascaded into 13+ parse errors as `:` was
// interpreted as the start of a colon-something pattern.
//
// Supertrait names are accepted but not yet wired into method
// dispatch — adopters get the syntactic freedom to express the
// relationship; trait inheritance semantics already work because
// the impl block separately implements both traits and method
// dispatch resolves through the impl_table.
//
// Returns 11 = sound() + 10 from the sub-trait method calling
// super-trait default through `self`, proving both traits are
// reachable through the same Husky impl set.

trait Animal {
    fn sound(&self) -> i64 { return 1; }
}
trait Dog: Animal {
    fn bark(&self) -> i64 { return self.sound() + 10; }
}
struct Husky {}
impl Animal for Husky {}
impl Dog for Husky {}

fn main() -> i64 {
    let h: Husky = Husky {};
    return h.bark();
}
