// v0.6.88 (probe finding 2026-05-02-assert-eq-ne-pointer-compare-
// extends-to-vec-struct-hashmap): canonical Rust `assert_eq!(a, b)`
// / `assert_ne!(a, b)` with no format args pre-fix lowered to
// `__nucleor_assert_eq(i64, i64)` which does pointer comparison.
// For str / String / derived-PartialEq struct values, this silently
// miscomputed — equal-content values at different heap addresses
// fail/pass incorrectly.
//
// Post-fix: textual rewrite at expand_format_macros — when no
// format args, rewrite to `if !((a) <op> (b)) { panic!("assertion
// failed"); };`. The existing v0.6.85 + v0.6.87 binop kind-4 auto-
// dispatch (str_eq / string_eq / <Type>__derived_eq) handles
// correctness transparently.
#[derive(PartialEq)]
struct Point { x: i64, y: i64 }

fn main() -> i32 {
    let s1: str = "hello";
    let s2: str = "hello";
    assert_eq!(s1, s2);     // pre-fix: false-fails (different addresses)
    print_int(11);

    let a: Point = Point { x: 5, y: 7 };
    let b: Point = Point { x: 5, y: 7 };
    assert_eq!(a, b);       // pre-fix: false-fails (different heap addrs)
    print_int(22);

    let c: Point = Point { x: 5, y: 8 };
    assert_ne!(a, c);
    print_int(33);
    return 0;
}
