// Audit F-MATH-003/F-MATH-004/F-MATH-005: ridge prediction must remain
// unbounded, rank must be callable repeatedly without leaking internal SVD
// handles, and eig must refuse non-symmetric matrices.

import "stdlib/rods/linalg.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let ad: f64 = if d < 0.0 { 0.0 - d } else { d };
    if ad < eps { return 1; };
    return 0;
}

fn check_ridge_unbounded() -> i64 {
    let x: i64 = linalg_new(3, 1);
    linalg_set_f64(x, 0, 0, 0.0);
    linalg_set_f64(x, 1, 0, 1.0);
    linalg_set_f64(x, 2, 0, 2.0);
    let y: i64 = linalg_new(3, 1);
    linalg_set_f64(y, 0, 0, 0.0);
    linalg_set_f64(y, 1, 0, 5.0);
    linalg_set_f64(y, 2, 0, 10.0);
    let model: i64 = linalg_ridge_solve_f64(x, y, 0.0);
    let pred: i64 = linalg_ridge_predict(model, x);
    let p2: f64 = linalg_get_f64(pred, 2, 0);
    linalg_free(x);
    linalg_free(y);
    linalg_free(model);
    linalg_free(pred);
    if p2 <= 1.0 { return 1; };
    return 0;
}

fn check_rank_repeated() -> i64 {
    let mut i: i64 = 0;
    while i < 200 {
        let m: i64 = linalg_new(2, 2);
        linalg_set_f64(m, 0, 0, 1.0);
        linalg_set_f64(m, 0, 1, 2.0);
        linalg_set_f64(m, 1, 0, 2.0);
        linalg_set_f64(m, 1, 1, 4.0);
        let r: i64 = linalg_rank_f64(m, 0.000000001);
        linalg_free(m);
        if r != 1 { return 2; };
        i = i + 1;
    };
    return 0;
}

fn check_eig_rejects_nonsymmetric() -> i64 {
    let m: i64 = linalg_new(2, 2);
    linalg_set_f64(m, 0, 0, 1.0);
    linalg_set_f64(m, 0, 1, 2.0);
    linalg_set_f64(m, 1, 0, 0.0);
    linalg_set_f64(m, 1, 1, 1.0);
    let e: i64 = linalg_eig(m);
    linalg_free(m);
    if e != 0 { return 4; };
    return 0;
}

fn check_eig_accepts_symmetric() -> i64 {
    let m: i64 = linalg_new(2, 2);
    linalg_set_f64(m, 0, 0, 2.0);
    linalg_set_f64(m, 0, 1, 0.0);
    linalg_set_f64(m, 1, 0, 0.0);
    linalg_set_f64(m, 1, 1, 3.0);
    let e: i64 = linalg_eig(m);
    linalg_free(m);
    if e == 0 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_ridge_unbounded();
    fails = fails + check_rank_repeated();
    fails = fails + check_eig_rejects_nonsymmetric();
    fails = fails + check_eig_accepts_symmetric();
    return fails;
}
