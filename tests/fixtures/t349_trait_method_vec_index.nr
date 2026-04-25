// t349_trait_method_vec_index.nr — v0.3.74 regression fixture.
//
// Pins indexed_element_full_type kind==8 (trait method call)
// resolution. Pre-v0.3.74, when a trait method returns Vec<f64>
// and the caller indexes the result inline (`s.samples()[i]`),
// the type resolver fell through to "" and the OUTER binop
// dispatched to integer add on packed-double bit patterns.
// Post-v0.3.74, the resolver mirrors the kind==7 free-fn-call
// branch but with the trait-impl mangled name (`<TYPE>__<METHOD>`).
//
// Returns 6 (1.0 + 2.0 + 3.0 = 6.0, cast to i32 then i64) if
// the f64 binop dispatch is correct.

#[repr(C)]
struct Stats { count: i64 }

trait Sample {
    fn samples(self) -> Vec<f64>;
}

impl Sample for Stats {
    fn samples(self) -> Vec<f64> {
        let mut r: Vec<f64> = Vec::new();
        r.push(1.0); r.push(2.0); r.push(3.0);
        return r;
    }
}

fn main() -> i64 {
    let s: Stats = Stats { count: 3 };
    // All three operands are trait-method-call indexed -- inline
    // arithmetic must dispatch to f64 add.
    let total: f64 = s.samples()[0] + s.samples()[1] + s.samples()[2];
    let i: i32 = total as i32;
    return i as i64;  // expect 6
}
