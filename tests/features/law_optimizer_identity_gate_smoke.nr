// R14-D2 Phase 2-prep gate — opt-in optimizer
// rewrite eligibility audit. The fixture pairs `@audit(law_opt_required)`
// with `@audit(check_laws_passed)` so the s1 compiler emits
// info[LAW-AUDIT-GATE] without halting. The IR-level
// `opt_law_rewrite_block` pass remains a no-op, so runtime
// semantics are unchanged. Phase 2 will use this same predicate
// to enable the first concrete rewrite (`f(a, identity) → a`).
//
// Expected build: rc=0 with info[LAW-AUDIT-GATE] in stdout.
// Expected run: rc=0 (semantics unchanged).

@audit(law_opt_required)
@audit(check_laws_passed)
@law(commutative, associative, identity = 0)
fn add_law_gated(a: i64, b: i64) -> i64 {
    return a + b;
}

@audit(check_laws_passed)
@law(commutative, associative, identity = 1)
fn mul_law_gated(a: i64, b: i64) -> i64 {
    return a * b;
}

fn main() -> i64 {
    if add_law_gated(7, 0) != 7 { return 1; };
    if add_law_gated(0, 9) != 9 { return 2; };
    if mul_law_gated(11, 1) != 11 { return 4; };
    if mul_law_gated(1, 13) != 13 { return 8; };
    return 0;
}
