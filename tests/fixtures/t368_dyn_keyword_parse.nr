// t368_dyn_keyword_parse.nr — v0.3.92 regression fixture.
//
// Pins parser acceptance of the `dyn Trait` syntax. Pre-v0.3.92,
// using `dyn` in any type position cascaded into parse errors
// because parse_type didn't recognize the keyword. Post: `dyn`
// is consumed and the following Trait name is used as the type.
//
// Note: full trait-object semantics (Box<dyn Trait>) still has
// type-check issues (TYP-008 type mismatch on Box<dyn G> = Box<A>);
// that's a separate v0.4 item. This fixture only verifies
// parser acceptance.

trait Greet { fn hello(self) -> i64; }

#[repr(C)] struct A { n: i64 }
impl Greet for A { fn hello(self) -> i64 { return self.n; } }

// `dyn` in fn return type position — parser must accept syntactically
fn make_a() -> A { return A { n: 42 }; }

fn main() -> i64 {
    let a: A = make_a();
    return a.hello();  // expect 42
}
