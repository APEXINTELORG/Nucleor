import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_knn_train_k_indices_i64 — raw k-nearest search returning
// indices only (no prediction).

fn main() -> i32 {
    let mut fail: i64 = 0;

    // 4 training rows: A(0,0), B(1,0), C(10,10), D(11,10).
    let mut td: Vec<f64> = Vec::new();
    td.push(0.0); td.push(0.0);
    td.push(1.0); td.push(0.0);
    td.push(10.0); td.push(10.0);
    td.push(11.0); td.push(10.0);
    let train: TensorF64 = tensor_f64_from_vec(4, 2, td);

    // Query at (0.5, 0.0). 1-nearest is index 0 (A) or 1 (B), both at dist 0.5.
    // Top 2 should be {0, 1} in some order.
    let mut qd: Vec<f64> = Vec::new();
    qd.push(0.5); qd.push(0.0);
    let q: TensorF64 = tensor_f64_from_vec(1, 2, qd);

    let idx: TensorI64 = knn_train_k_indices_i64(&train, &q, 2);
    if idx.shape.rows != 1 { print("FAIL idx rows"); fail = fail + 1; };
    if idx.shape.cols != 2 { print("FAIL idx cols"); fail = fail + 1; };

    let i0: i64 = tensor_i64_at(&idx, 0, 0);
    let i1: i64 = tensor_i64_at(&idx, 0, 1);
    // The two nearest must be A(0) and B(1).
    let i_min: i64 = if i0 < i1 { i0 } else { i1 };
    let i_max: i64 = if i0 > i1 { i0 } else { i1 };
    if i_min != 0 { print("FAIL idx min"); fail = fail + 1; };
    if i_max != 1 { print("FAIL idx max"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_knn_train_k_indices_i64"); return 0; };
    print("FAIL ml_recover_knn_train_k_indices_i64");
    return 1;
}
