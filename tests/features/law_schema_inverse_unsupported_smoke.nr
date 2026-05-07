// R14 Phase 3b broad property pack: bounded `inverse = g` is now
// generated. This fixture keeps the original counterexample shape
// (`id_law` claiming `neg_law` as its inverse — false:
// `id_law(neg_law(7))` returns `-7`, not `7`) so the generator
// catches it as LAW-001. The fixture name is kept for verify-suite
// continuity; positive-inverse coverage lives in
// `law_inverse_bounded_smoke.nr`, malformed-`inverse =` coverage
// in `law_schema_malformed_inverse_smoke.nr`.
//
// Expected plain run: rc=0.
// Expected with `nuc test --check-laws`: nonzero, LAW-001 with
// "inverse counterexample for id_law" diagnostic.

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
