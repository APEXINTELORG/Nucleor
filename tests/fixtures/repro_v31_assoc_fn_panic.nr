// v0.4.31 silent-miscompute closure: unsupported `Type::method(...)`
// associated-fn calls used to lower to `const_int(0)` and continue,
// producing a binary that returned 0 silently. Now panics.
//
// This fixture is a NEGATIVE test — running the compiler on it must
// exit non-zero with an error mentioning "unsupported associated-fn".
// EXPECT: panic
struct Foo { x: i64 }

fn main() -> i64 {
    // `Foo::nonexistent_method(...)` is not a supported associated fn.
    // Pre-v0.4.31: the compiler printed an ERROR but lowered to 0,
    // and main() returned 0 — silent green. Post-v0.4.31: panic.
    let r: i64 = Foo::nonexistent_method(1, 2);
    return r;
}
