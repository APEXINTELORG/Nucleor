// T1.5c (v0.2.342) smoke: resolver-layer name privatization with
// opt-in semantics. Imports two fixture libraries:
//   - tests/smoke/t15c_pkg/lib_optin.nr  (has `pub fn` → opt-in)
//   - tests/smoke/t15c_pkg/lib_legacy.nr (no `pub fn` → opt-out)
//
// Verifies:
//   - cross-module calls to `pub fn` from opt-in lib succeed
//   - cross-module calls to non-pub fn from opt-out lib succeed
//     (back-compat for v0.1.x rod files that have no pub markers)
//
// The negative case (cross-module call to non-pub fn from an opt-in
// lib must FAIL at compile/link time) is covered by the err-fixture
// added separately (when the err/ regression suite is plumbed in
// T1.5d). For now it's verified manually.

import "./t15c_pkg/lib_optin.nr";
import "./t15c_pkg/lib_legacy.nr";

#[test]
fn test_cross_module_pub_call_opt_in_lib() {
    // lib_pub_api is `pub fn` so it's callable cross-module.
    // It internally calls lib_helper which IS privatized in opt-in
    // mode — but the call is intra-module so the rewriter rewrites
    // both the declaration and the call together, keeping it linked.
    assert_eq(lib_pub_api(), 107);
}

#[test]
fn test_cross_module_non_pub_call_opt_out_lib() {
    // legacy_fn is non-pub but lib_legacy has no pub fn at all → the
    // resolver's opt-in detection sees no pub markers and skips
    // privatization entirely. legacy_fn stays globally callable.
    assert_eq(legacy_fn(), 42);
}
