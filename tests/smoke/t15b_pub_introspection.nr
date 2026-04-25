// T1.5b (v0.2.341) smoke: `pub` keyword is parsed and tagged on
// top-level items via a kind-76 marker node. Visibility surfaces in
// `nuc summary` (renders `pub fn` vs `fn`) and is available to the
// (future) T1.5c resolver-layer privatization.
//
// Enforcement is NOT online yet. A non-pub fn is still callable from
// other modules — these tests verify the marker mechanism is correctly
// emitted and the runtime behavior of pub/non-pub fns is unchanged.

pub fn pub_alpha() -> i64 { return 11; }
fn priv_beta() -> i64 { return 22; }
pub fn pub_gamma() -> i64 { return 33; }
fn priv_delta() -> i64 { return 44; }

#[test]
fn test_pub_fn_callable() {
    assert_eq(pub_alpha(), 11);
    assert_eq(pub_gamma(), 33);
}

#[test]
fn test_non_pub_fn_still_callable_pre_enforcement() {
    // T1.5c will gate cross-module access. Within the same file
    // non-pub fns are always callable — verifies the marker
    // mechanism doesn't break intra-module calls.
    assert_eq(priv_beta(), 22);
    assert_eq(priv_delta(), 44);
}

#[test]
fn test_mixed_pub_arithmetic() {
    let total: i64 = pub_alpha() + priv_beta() + pub_gamma() + priv_delta();
    assert_eq(total, 110);
}
