// R14 Phase 3b: float/approximate law modifiers fail closed until
// the tolerance contract ships.
//
// Expected plain run: rc=0.
// Expected with `nuc test --check-laws`: nonzero, LAW-004.

@law(approximate)
fn plus_one(a: i64) -> i64 {
    return a + 1;
}

fn main() -> i64 {
    return 0;
}
