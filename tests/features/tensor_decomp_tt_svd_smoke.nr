// v0.8.258 stdlib/rods/tensor_decomp.nr tt_svd_3d arity drift FIX coverage.
//
// Pre-v0.8.258 the rod declared `nuc_td_tt_svd_3d` 6-arg
// `(X, n1, n2, n3, r1, r2)` but C runtime took 5
// `(X, n1, n2, n3, max_rank)`. Rod's `r2` was silently dropped by
// Windows x64 calling convention; rod's `r1` was used as max_rank.
// No silent miscompute (single rank cap was applied) but the API
// claimed two distinct bond-dim parameters. HIGH severity,
// "wrong-error" class.
//
// Same arity-drift family as v0.8.45 ML-1, v0.8.252 kv_cache,
// v0.8.254 transformer, v0.8.255 bayesian, v0.8.256 quantize,
// v0.8.257 sparse. Surfaced by TRACK A
// `extern_arity_drift_tensor_decomp_2026-05-05`.
//
// Fix (Plan B, non-breaking):
// - C `nuc_td_tt_svd_3d` 5-arg renamed to `_max_rank`.
// - New 6-arg `nuc_td_tt_svd_3d(X, n1, n2, n3, r1, r2)` collapses
//   `r1` and `r2` to `max(r1, r2)` and forwards. Rationale: current
//   implementation uses one rank cap for both bonds; max-of-two is
//   the conservative cap. Future Phase B may refactor to true
//   per-bond ranks.
// - Rod exposes both `tdecomp_tt_svd_3d` (6-arg) and
//   `tdecomp_tt_svd_3d_max_rank` (5-arg).
//
// Locks invariants on a 2×2×2 tensor:
//   1. 6-arg returns non-zero handle with non-trivial body —
//      header (6 longs) + at least one core element.
//   2. 6-arg with r1=r2=2 matches 5-arg max_rank=2 — same len.
//
// Expected: rc=0.

import "stdlib/rods/tensor_decomp.nr"

fn make_x_222() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(2.0));
    v.push(f64_to_bits(3.0));
    v.push(f64_to_bits(4.0));
    v.push(f64_to_bits(5.0));
    v.push(f64_to_bits(6.0));
    v.push(f64_to_bits(7.0));
    v.push(f64_to_bits(8.0));
    return v;
}

fn check_6arg_returns_valid() -> i64 {
    let x: Vec<i64> = make_x_222();
    let h: i64 = tdecomp_tt_svd_3d(x, 2, 2, 2, 2, 2);
    if h == 0 { return 1; };
    if vec_len(h) <= 6 { return 2; }; // header is 6 longs; cores must add at least one
    return 0;
}

fn check_6arg_matches_5arg() -> i64 {
    let x6: Vec<i64> = make_x_222();
    let h6: i64 = tdecomp_tt_svd_3d(x6, 2, 2, 2, 2, 2);
    let x5: Vec<i64> = make_x_222();
    let h5: i64 = tdecomp_tt_svd_3d_max_rank(x5, 2, 2, 2, 2);
    if vec_len(h6) != vec_len(h5) { return 4; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_6arg_returns_valid();
    fails = fails + check_6arg_matches_5arg();
    return fails;
}
