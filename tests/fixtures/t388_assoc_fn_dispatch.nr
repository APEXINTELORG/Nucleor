// t388_assoc_fn_dispatch.nr — v0.3.111 regression fixture.
//
// Pins user-defined associated fn dispatch (`Type::method(...)`)
// AND the `Self` return-type substitution. Pre-v0.3.111, two
// related silent miscomputes hit the canonical Rust constructor
// pattern:
//
//   1. `impl Point { fn new(x: i64, y: i64) -> Self { ... } }`
//      left rtype = "Self" verbatim. populate_fn_returns_in_sym
//      registered `__fnret_Point__new = "Self"`, which doesn't
//      resolve to a known struct in expr_struct_type.
//   2. The kind-12 (assoc-fn-call) lowering only recognized the
//      built-in Type::method handlers (Vec::new, HashMap::new,
//      Tensor::*, enum-variant ctor). User-defined assoc fns
//      (`Point::new(...)`) hit the diagnostic-and-return-0 path —
//      a printed error followed by silent miscompute (the .exe
//      still ran, returning 0 from the constructor, then
//      `p.sum()` operated on the zero placeholder).
//
// Adopters reaching for the canonical `let p = Point::new(...)`
// pattern got either segfault, wrong values, or zeros — all silent
// at runtime since the diag was just informational.
//
// Fix: substitute Self/&Self/&mut Self in the parsed return type
// at parse_impl_block; add a __fnret_<mangled>-based dispatch in
// the kind-12 lowering before the diagnostic that emits a normal
// i64 fn call to the synthesized impl method.
//
// Returns 10 = 7 + 3 from a Self-returning constructor + a
// self-taking method, proving both halves of the round-trip.

struct Point { x: i64, y: i64 }
impl Point {
    fn new(x: i64, y: i64) -> Self { return Point { x: x, y: y }; }
    fn sum(self) -> i64 { return self.x + self.y; }
}

fn main() -> i64 {
    let p: Point = Point::new(7, 3);
    return p.sum();
}
