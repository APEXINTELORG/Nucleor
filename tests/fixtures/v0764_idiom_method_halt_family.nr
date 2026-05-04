// v0.7.64 consolidated negative fixture — Rust idiom-method halt family.
// Replaces 6 single-method fixtures (v0730 int, v0731 char, v0732 string,
// v0733 vec, v0734 iter-conversion, v0740 ownership-conversion) with one
// file. All 77+ method names in v0.6.82's idiom-list halt converge on
// the same kind-8 method-dispatch catch-all path.
//
// To pivot to a different family member, swap the body line. The fixture
// only needs to fire ONE of them to validate the halt path; the message
// shape is identical (just method name differs).
//
// NOTE: literal-receiver shape (`5.abs()`, not `let i = 5; i.abs()`) is
// required to hit the v0.6.82 path — bound-variable receivers go through
// the type-checker's earlier TYP-007 receiver-type-mismatch halt instead.
fn main() -> i64 {
    // v0.7.30 — integer-intrinsic methods (.abs/.pow/.signum/...)
    let x: i64 = 5.abs();
    return 0;
}
