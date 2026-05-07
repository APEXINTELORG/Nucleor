// R14 Phase 3b broad property pack: bounded integer `inverse = g`
// is now a generated low-risk law under `nuc test --check-laws`.
// `negate` is its own inverse (negate(negate(a)) == a) and the
// generator emits both round-trip directions at four sample
// integers (positive, negative, small-magnitude, zero-adjacent).
//
// Expected plain run: rc=0.
// Expected with `nuc test --check-laws`: rc=0 plus generated
// __nucleor_law_check_* tests, including the inverse round-trips.

@law(inverse = negate)
fn negate(a: i64) -> i64 {
    return 0 - a;
}

fn main() -> i64 {
    if negate(negate(7)) != 7 { return 1; };
    if negate(negate(0 - 3)) != 0 - 3 { return 2; };
    if negate(negate(5)) != 5 { return 3; };
    if negate(negate(0 - 1)) != 0 - 1 { return 4; };
    return 0;
}
