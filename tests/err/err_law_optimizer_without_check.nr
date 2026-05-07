// EXPECT: LAW-003 optimizer rewrite gate without check-laws audit
// R14-D2 Phase 2-prep gate (local-claude2 v0842) — declaring
// `@audit(law_opt_required)` without `@audit(check_laws_passed)`
// must fail closed with LAW-003 before any IR is emitted. Adopters
// who add `@audit(law_opt_required)` to a file whose law family
// they have not validated under `nuc test --check-laws` get a hard
// build error instead of silently letting a future law-rewrite
// pass act on unverified law metadata.

@audit(law_opt_required)
@law(commutative, associative, identity = 0)
fn add_law_no_audit(a: i64, b: i64) -> i64 {
    return a + b;
}

fn main() -> i64 {
    return 0;
}
