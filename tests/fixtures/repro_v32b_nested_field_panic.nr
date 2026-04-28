// v0.4.32b silent-miscompute closure: nested struct field assignment
// `outer.inner.field = X` used to print ERROR but compile + return cur
// silently — the assignment was DROPPED, the binary ran with the
// inner field unchanged. Now panics.
// EXPECT: panic
struct Inner { v: i64 }
struct Outer { inner: Inner }

fn main() -> i64 {
    let mut o: Outer = Outer { inner: Inner { v: 0 } };
    o.inner.v = 42;  // nested write — was silent miscompute
    return o.inner.v;
}
