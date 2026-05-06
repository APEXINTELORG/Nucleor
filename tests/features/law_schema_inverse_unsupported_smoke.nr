// R14 Phase 3b: canonical but unsupported law forms fail closed
// under `nuc test --check-laws` instead of being silently accepted.
//
// Expected plain run: rc=0.
// Expected with `nuc test --check-laws`: nonzero, LAW-001.

fn neg_law(a: i64) -> i64 {
    return 0 - a;
}

@law(inverse = neg_law)
fn id_law(a: i64) -> i64 {
    return a;
}

fn main() -> i64 {
    return 0;
}
