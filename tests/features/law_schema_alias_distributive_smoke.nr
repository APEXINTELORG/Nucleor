// R14 Phase 2a: bare `distributive` is rejected by
// `nuc test --check-laws` with LAW-007. Plain build/run remains valid.
//
// Expected plain run: rc=0.
// Expected with `nuc test --check-laws`: nonzero, LAW-007.

@law(distributive)
fn mul_law(a: i64, b: i64) -> i64 {
    return a * b;
}

fn main() -> i64 {
    return 0;
}
