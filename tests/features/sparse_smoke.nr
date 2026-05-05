// v0.8.170 stdlib/rods/sparse.nr first test coverage.
//
// Sparse matrix CSR + COO construction + mat-vec. Pre-v0.8.170:
// zero coverage.
//
// Locks four textbook sparse-matrix invariants on a 3×3 identity
// matrix:
//   1. **Construction shape**: from_coo(I_3) → rows=3, cols=3,
//      nnz=3.
//   2. **get(i, i) == 1.0** on identity diagonal.
//   3. **get(i, j) == 0** for i != j (CSR returns 0 for missing
//      entries).
//   4. **Mat-vec preserves x**: I·x == x for any x.
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

fn make_identity_3() -> i64 {
    let mut rows: Vec<i64> = Vec::new();
    let mut cols: Vec<i64> = Vec::new();
    let mut vals: Vec<i64> = Vec::new();
    rows.push(0); cols.push(0); vals.push(f64_to_bits(1.0));
    rows.push(1); cols.push(1); vals.push(f64_to_bits(1.0));
    rows.push(2); cols.push(2); vals.push(f64_to_bits(1.0));
    return sparse_from_coo(rows, cols, vals, 3, 3, 3);
}

fn check_shape() -> i64 {
    let m: i64 = make_identity_3();
    if sparse_rows(m) != 3 { sparse_free(m); return 1; };
    if sparse_cols(m) != 3 { sparse_free(m); return 2; };
    if sparse_nnz(m) != 3 { sparse_free(m); return 4; };
    sparse_free(m);
    return 0;
}

fn check_get_diagonal() -> i64 {
    let m: i64 = make_identity_3();
    if close(sparse_get(m, 0, 0), f64_to_bits(1.0), 1e-9) != 1 { sparse_free(m); return 8; };
    if close(sparse_get(m, 1, 1), f64_to_bits(1.0), 1e-9) != 1 { sparse_free(m); return 16; };
    if close(sparse_get(m, 2, 2), f64_to_bits(1.0), 1e-9) != 1 { sparse_free(m); return 32; };
    sparse_free(m);
    return 0;
}

fn check_get_off_diagonal() -> i64 {
    let m: i64 = make_identity_3();
    if close(sparse_get(m, 0, 1), f64_to_bits(0.0), 1e-9) != 1 { sparse_free(m); return 64; };
    if close(sparse_get(m, 1, 2), f64_to_bits(0.0), 1e-9) != 1 { sparse_free(m); return 128; };
    if close(sparse_get(m, 2, 0), f64_to_bits(0.0), 1e-9) != 1 { sparse_free(m); return 256; };
    sparse_free(m);
    return 0;
}

fn check_mat_vec_identity() -> i64 {
    let m: i64 = make_identity_3();
    let mut x: Vec<i64> = Vec::new();
    x.push(f64_to_bits(7.0));
    x.push(f64_to_bits(8.0));
    x.push(f64_to_bits(9.0));
    let y: i64 = sparse_mul_vec(m, x);
    if close(vec_get(y, 0), f64_to_bits(7.0), 1e-9) != 1 { sparse_free(m); return 512; };
    if close(vec_get(y, 1), f64_to_bits(8.0), 1e-9) != 1 { sparse_free(m); return 1024; };
    if close(vec_get(y, 2), f64_to_bits(9.0), 1e-9) != 1 { sparse_free(m); return 2048; };
    sparse_free(m);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_shape();
    fails = fails + check_get_diagonal();
    fails = fails + check_get_off_diagonal();
    fails = fails + check_mat_vec_identity();
    return fails;
}
