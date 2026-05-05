// v0.8.211 stdlib/rods/linalg.nr first test coverage.
//
// Dense linear algebra (lifecycle, arithmetic, decompositions —
// LU, QR, Cholesky, eigen, SVD; rank; solve; ridge regression).
// Pre-v0.8.211: zero coverage on the standalone rod.
//
// Locks four foundational matrix invariants — heavier
// decompositions are exercised in dedicated ML ships:
//
//   1. **Identity construction** — eye(3) → 3×3, diagonal 1,
//      off-diagonal 0.
//   2. **Trace of I_n == n** — sum of diagonal.
//   3. **Determinant of I_n == 1** — by definition.
//   4. **Transpose round-trip** — transpose(transpose(A)) shape
//      and entries match A.
//
// Expected: rc=0.

import "stdlib/rods/linalg.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_identity_construction() -> i64 {
    let m: i64 = linalg_eye(3);
    if linalg_rows(m) != 3 { linalg_free(m); return 1; };
    if linalg_cols(m) != 3 { linalg_free(m); return 2; };
    if close(linalg_get(m, 0, 0), f64_to_bits(1.0), 1e-12) != 1 { linalg_free(m); return 4; };
    if close(linalg_get(m, 1, 1), f64_to_bits(1.0), 1e-12) != 1 { linalg_free(m); return 8; };
    if close(linalg_get(m, 2, 2), f64_to_bits(1.0), 1e-12) != 1 { linalg_free(m); return 16; };
    if close(linalg_get(m, 0, 1), f64_to_bits(0.0), 1e-12) != 1 { linalg_free(m); return 32; };
    if close(linalg_get(m, 1, 0), f64_to_bits(0.0), 1e-12) != 1 { linalg_free(m); return 64; };
    linalg_free(m);
    return 0;
}

fn check_trace_identity() -> i64 {
    let m: i64 = linalg_eye(5);
    let t: i64 = linalg_trace(m);
    linalg_free(m);
    if close(t, f64_to_bits(5.0), 1e-9) != 1 { return 128; };
    return 0;
}

fn check_det_identity() -> i64 {
    let m: i64 = linalg_eye(4);
    let d: i64 = linalg_det(m);
    linalg_free(m);
    if close(d, f64_to_bits(1.0), 1e-9) != 1 { return 256; };
    return 0;
}

fn check_transpose_round_trip() -> i64 {
    let a: i64 = linalg_new(2, 3);
    linalg_set(a, 0, 0, f64_to_bits(1.0));
    linalg_set(a, 0, 1, f64_to_bits(2.0));
    linalg_set(a, 0, 2, f64_to_bits(3.0));
    linalg_set(a, 1, 0, f64_to_bits(4.0));
    linalg_set(a, 1, 1, f64_to_bits(5.0));
    linalg_set(a, 1, 2, f64_to_bits(6.0));

    let at: i64 = linalg_transpose(a);
    let att: i64 = linalg_transpose(at);

    if linalg_rows(att) != 2 { linalg_free(a); linalg_free(at); linalg_free(att); return 512; };
    if linalg_cols(att) != 3 { linalg_free(a); linalg_free(at); linalg_free(att); return 1024; };
    if close(linalg_get(att, 0, 1), f64_to_bits(2.0), 1e-12) != 1 { linalg_free(a); linalg_free(at); linalg_free(att); return 2048; };
    if close(linalg_get(att, 1, 2), f64_to_bits(6.0), 1e-12) != 1 { linalg_free(a); linalg_free(at); linalg_free(att); return 4096; };

    linalg_free(a);
    linalg_free(at);
    linalg_free(att);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_identity_construction();
    fails = fails + check_trace_identity();
    fails = fails + check_det_identity();
    fails = fails + check_transpose_round_trip();
    return fails;
}
