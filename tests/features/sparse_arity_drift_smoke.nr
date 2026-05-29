// v0.8.257 stdlib/rods/sparse.nr from_coo arity drift FIX coverage.
//
// Pre-v0.8.257 the rod declared `nuc_sp_from_coo` 6-arg
// `(row, col, val, rows, cols, nnz)` but C runtime took 5 — the C
// function derived nnz from row->len and the rod's 6th arg was
// silently dropped by the Windows x64 calling convention. No
// silent miscompute (the C function got correct nnz from the Vec
// length) but the public rod API did not match runtime semantics.
//
// HIGH severity (rod-overdeclares-C, "wrong-error" class). Same
// arity-drift family as v0.8.45 ML-1, v0.8.252 kv_cache, v0.8.254
// transformer, v0.8.255 bayesian, v0.8.256 quantize. Surfaced by
// TRACK A `extern_arity_drift_sparse_2026-05-05`.
//
// Fix (Plan B, non-breaking):
// - C `nuc_sp_from_coo` 5-arg renamed to `_inferred`.
// - New 6-arg `nuc_sp_from_coo(row, col, val, rows, cols, nnz)` accepts
//   the caller's nnz hint (informational; canonical nnz is row->len)
//   and forwards to `_inferred`.
// - Rod exposes both forms via `sparse_from_coo` (6-arg) and
//   `sparse_from_coo_inferred` (5-arg).
//
// Locks invariants on a 2×2 identity built from COO:
//   1. 6-arg from_coo round-trip — sparse_get diagonal = 1.0,
//      off-diagonal = 0.0; rows/cols/nnz accessors match.
//   2. 5-arg `_inferred` matches 6-arg — same matrix produces
//      same get / rows / cols / nnz.
//
// Expected: rc=0.

import "stdlib/rods/sparse.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_row_idx() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(0);
    v.push(1);
    return v;
}

fn make_col_idx() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(0);
    v.push(1);
    return v;
}

fn make_vals() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(1.0));
    return v;
}

fn check_6arg_round_trip() -> i64 {
    let r: Vec<i64> = make_row_idx();
    let c: Vec<i64> = make_col_idx();
    let v: Vec<i64> = make_vals();
    let h: i64 = sparse_from_coo(r, c, v, 2, 2, 2);
    if h == 0 { return 1; };
    if sparse_rows(h) != 2 { sparse_free(h); return 2; };
    if sparse_cols(h) != 2 { sparse_free(h); return 4; };
    if sparse_nnz(h) != 2 { sparse_free(h); return 8; };
    if close(sparse_get(h, 0, 0), f64_to_bits(1.0), 1e-9) != 1 { sparse_free(h); return 16; };
    if close(sparse_get(h, 1, 1), f64_to_bits(1.0), 1e-9) != 1 { sparse_free(h); return 32; };
    if close(sparse_get(h, 0, 1), f64_to_bits(0.0), 1e-9) != 1 { sparse_free(h); return 64; };
    sparse_free(h);
    return 0;
}

fn check_5arg_inferred_matches() -> i64 {
    let r6: Vec<i64> = make_row_idx();
    let c6: Vec<i64> = make_col_idx();
    let v6: Vec<i64> = make_vals();
    let h6: i64 = sparse_from_coo(r6, c6, v6, 2, 2, 2);

    let r5: Vec<i64> = make_row_idx();
    let c5: Vec<i64> = make_col_idx();
    let v5: Vec<i64> = make_vals();
    let h5: i64 = sparse_from_coo_inferred(r5, c5, v5, 2, 2);

    if sparse_rows(h6) != sparse_rows(h5) { sparse_free(h6); sparse_free(h5); return 128; };
    if sparse_cols(h6) != sparse_cols(h5) { sparse_free(h6); sparse_free(h5); return 256; };
    if sparse_nnz(h6) != sparse_nnz(h5) { sparse_free(h6); sparse_free(h5); return 512; };
    if sparse_get(h6, 0, 0) != sparse_get(h5, 0, 0) { sparse_free(h6); sparse_free(h5); return 1024; };
    if sparse_get(h6, 1, 1) != sparse_get(h5, 1, 1) { sparse_free(h6); sparse_free(h5); return 2048; };
    sparse_free(h6); sparse_free(h5);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_6arg_round_trip();
    fails = fails + check_5arg_inferred_matches();
    return fails;
}
