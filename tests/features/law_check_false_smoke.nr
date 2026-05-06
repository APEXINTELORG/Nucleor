// R14 Phase 2a: false @law declarations must fail under
// `nuc test --check-laws` with LAW-001. Plain build/run remains
// valid so the normal feature sweep can include this fixture.
//
// Expected plain run: rc=0.
// Expected with `nuc test --check-laws`: nonzero, LAW-001.

@law(commutative)
fn sub_law(a: i64, b: i64) -> i64 {
    return a - b;
}

fn main() -> i64 {
    return 0;
}
