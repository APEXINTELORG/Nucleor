// v0.6.93 (correctness fix): explicit `self: &Self` param shape
// in impl-block methods. Pre-fix only the SHORTHAND `&self` /
// `self` form got `Self` substituted with the impl's concrete
// type_name; the explicit `self: &Self` / `self: &mut Self`
// shape left "Self" in the param type string verbatim. Downstream
// `self.field` field access then failed (`expr_struct_type`
// couldn't map "Self" to a known struct), surfacing as the
// generic "cannot resolve field access type" panic.
//
// Post-fix: parse_impl_block substitutes Self / &Self / &mut Self
// in the EXPLICIT param-type form too, mirroring the v0.3.111
// return-type substitution.
struct Counter { n: i64 }

impl Counter {
    fn new() -> Self {
        return Counter { n: 0 };
    }
    fn add(self: &Self, x: i64) -> i64 {
        return self.n + x;
    }
    fn replace(self: &mut Self, n: i64) -> i64 {
        return n;
    }
}

fn main() -> i32 {
    let c: Counter = Counter::new();
    print_int(c.add(5) as i32);    // 5 (0 + 5)
    let d: Counter = Counter { n: 10 };
    print_int(d.add(3) as i32);    // 13
    return 0;
}
