// R14 Phase 3b: f64 law checking fails closed until tolerance
// semantics ship.
//
// Expected plain run: rc=0.
// Expected with `nuc test --check-laws`: nonzero, LAW-004.

@law(associative)
fn add_f64(a: f64, b: f64) -> f64 {
    return a + b;
}

fn main() -> i64 {
    return 0;
}
