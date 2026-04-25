// T2.5 (v0.2.351) smoke: lifetime parameters (parse-only).
// `'a` lifetime annotations are recognized in:
//   - generic param lists: fn foo<'a>(x: i64) -> i64
//   - reference types:     &'a T   /   &'a mut T
//   - struct generics:     struct Holder<'a, T> { ... }
//   - generic instantiations: Holder<'a, T>
//
// Annotations are advisory metadata only — the existing dynamic-scope
// borrow checker still enforces ownership. Real lifetime-parameter
// checking lands in T2.5b once the borrow checker tracks named scopes.

fn no_lifetime(x: i64) -> i64 { return x + 1; }

fn with_lifetime<'a>(x: i64) -> i64 { return x + 2; }

fn with_two_lifetimes<'a, 'b>(x: i64, y: i64) -> i64 { return x + y; }

fn mixed_params<'a, T>(x: i64) -> i64 { return x; }

#[test]
fn test_no_lifetime_baseline() {
    // Sanity: existing fns without lifetime annotations still work.
    assert_eq(no_lifetime(10), 11);
}

#[test]
fn test_single_lifetime() {
    assert_eq(with_lifetime(10), 12);
}

#[test]
fn test_two_lifetimes() {
    assert_eq(with_two_lifetimes(10, 20), 30);
}

#[test]
fn test_mixed_lifetime_and_type_param() {
    assert_eq(mixed_params(42), 42);
}
