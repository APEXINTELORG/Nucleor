// EXPECT: TYP-011 assert_eq! on str arguments does pointer comparison
//
// v0.6.20 (probe finding 2026-05-01-assert-eq-ne-macros-silent-miscompute-on-str):
// pre-fix `assert_eq!("hello", "hello")` always FAILED at runtime
// because the macro lowered to i64 comparison on the str pointers.
// Equal-content strs at different addresses returned !=, so the
// assertion fired even when content matched. v0.6.20 catches this
// at type-check time with a TYP-011 diagnostic + workaround pointer
// (use `assert_eq(str_eq(a, b), 1)`).

fn main() -> i32 {
    assert_eq!("hello", "hello");
    print("OK");
    return 0;
}
