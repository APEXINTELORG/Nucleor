// t365_trait_generic_method.nr — v0.3.89 regression fixture.
//
// Pins parser support for generic params on trait methods:
// `trait T { fn count<U>(self) -> i64; }`. Pre-v0.3.89, the
// trait body parser called `expect_tok(50)` (i.e. `(` after the
// method name) and got `<` instead, cascading into 22+ parse
// errors with no main entry produced.
//
// Post-v0.3.89: the generic-param shape is consumed and discarded
// (Nucleor's trait dispatch is monomorphic-by-mangled-name, so
// generic types resolve at impl time). Impl block was already
// handling generic params via parse_generic_params.
//
// Returns 3 if trait method with generic param dispatches to impl.

trait Container { fn count<T>(self) -> i64; }

#[repr(C)]
struct Box1 { items: Vec<i64> }

impl Container for Box1 {
    fn count<T>(self) -> i64 { return vec_len(self.items); }
}

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1); v.push(2); v.push(3);
    let b: Box1 = Box1 { items: v };
    return b.count();
}
