// R14 Phase 3b broad property pack: malformed `inverse =` (empty
// partner-fn name) fails closed under `nuc test --check-laws`
// instead of being silently accepted. The plain build/run path
// remains valid so the normal feature sweep can include this
// fixture.
//
// Expected plain run: rc=0.
// Expected with `nuc test --check-laws`: nonzero, LAW-001 with
// "inverse law requires a partner function name" diagnostic.

@law(inverse =)
fn id_law_malformed(a: i64) -> i64 {
    return a;
}

fn main() -> i64 {
    return 0;
}
