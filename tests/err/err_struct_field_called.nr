// EXPECT: error[TYP-015] is a FIELD on struct
// v0.4.123: `p.x(42)` where `x` is a struct field (not a method)
// silently lowered to `vec_x(p, 42)` and surfaced via the v0.4.106
// TYP-005 lift as `error[TYP-005]: undefined function `vec_x()``
// — confusing because the source has nothing to do with Vec.
// Now halts at codegen with TYP-015 naming the field and the
// struct, suggesting the right syntax (`p.<field>` to read,
// `p.<field> = <value>;` to assign).

struct P { x: i64 }

fn main() -> i32 {
    let p: P = P { x: 5 };
    p.x(42);
    0
}
