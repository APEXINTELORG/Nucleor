// t404_enum_equality.nr — v0.3.128 regression fixture.
//
// Pins enum-variant equality dispatch. Pre-v0.3.128, `t == Tag::A`
// (where t is a `Tag` enum value) compared the underlying Vec
// pointers — each Tag::A constructor allocates a fresh Vec, so
// pointer equality was always false. Silent miscompute for every
// enum-discriminator comparison adopters wrote, including the
// canonical state-machine pattern below.
//
// HIGH-blast for state machines, parser dispatch tables, AST
// walkers, and any code that reaches for `match` would've used
// equality if the target were just-discriminator (vs pattern).
//
// Fix: in lower_expr kind-4 (binop), if the op is `==` (token 30)
// or `!=` (token 31), check whether either operand is a kind-12
// associated-fn-call matching a registered enum etag (sym key
// `__etag_<tname>_<mname>`). When yes, lower as a tag compare:
// extract `vec_get(_, 0)` from both sides and compare those i64s.
//
// Returns 0 when all three Tag values dispatch to the right branch
// (1+2+3 = 6 — but with the !=  branch we get 0).

enum Tag { A, B, C }

fn classify(t: Tag) -> i64 {
    if t == Tag::A { return 1; };
    if t == Tag::B { return 2; };
    if t == Tag::C { return 3; };
    return 0;
}

fn main() -> i64 {
    let a: i64 = classify(Tag::A);
    let b: i64 = classify(Tag::B);
    let c: i64 = classify(Tag::C);
    if a != 1 { return 10; };
    if b != 2 { return 20; };
    if c != 3 { return 30; };
    // != also exercised
    let t: Tag = Tag::A;
    if t != Tag::B { return 0; };
    return 99;
}
