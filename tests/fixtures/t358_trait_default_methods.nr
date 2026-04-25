// t358_trait_default_methods.nr — v0.3.82 regression fixture.
//
// Pins trait default-method support. Pre-v0.3.82, calling a trait
// method that the impl didn't override fell through to the
// `vec_<mname>` fallback in the kind-8 dispatch path — producing
// the cryptic clang link error `use of undefined value '@vec_world'`.
// Post-v0.3.82, a new pass after collect_impls walks every impl with
// a trait_name and synthesizes mangled fns from the trait's default
// bodies for any method the impl didn't override.
//
// Returns 0 on success; non-zero is which check failed.

trait Greet {
    fn hello(self) -> i64;                  // required
    fn world(self) -> i64 { return 100; }   // default impl
    fn combined(self) -> i64 { return self.hello() + 50; }
        // default that calls another trait method
}

#[repr(C)]
struct G { n: i64 }

impl Greet for G {
    fn hello(self) -> i64 { return self.n; }
    // world() and combined() should fall back to defaults
}

#[repr(C)]
struct H { n: i64 }

impl Greet for H {
    fn hello(self) -> i64 { return self.n * 2; }
    fn world(self) -> i64 { return 999; }   // explicit override
    // combined() still uses default
}

fn main() -> i64 {
    let g: G = G { n: 5 };
    let h: H = H { n: 3 };

    if g.hello() != 5 { return 91; };
    if g.world() != 100 { return 92; };       // default

    if h.hello() != 6 { return 93; };
    if h.world() != 999 { return 94; };       // override

    return 0;
}
