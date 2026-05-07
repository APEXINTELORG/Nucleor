import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_knn_1nn_distances_f64 — distances only, no label lookup.
// 4 training points; query 1 row → distance to nearest neighbor.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut td: Vec<f64> = Vec::new();
    td.push(0.0); td.push(0.0);
    td.push(3.0); td.push(4.0);
    td.push(10.0); td.push(10.0);
    td.push(20.0); td.push(20.0);
    let train_x: TensorF64 = tensor_f64_from_vec(4, 2, td);

    let mut yd: Vec<i64> = Vec::new();
    yd.push(0); yd.push(0); yd.push(1); yd.push(1);
    let train_y: TensorI64 = tensor_i64_from_vec(4, 1, yd);

    let model: KnnClassifierF64 = knn_classifier_f64(train_x, train_y);

    // Query at (3, 4) — perfect match to training row 1, distance 0.
    let mut qd: Vec<f64> = Vec::new();
    qd.push(3.0); qd.push(4.0);
    let q: TensorF64 = tensor_f64_from_vec(1, 2, qd);

    let dists: TensorF64 = knn_1nn_distances_f64(&model, &q);
    if dists.shape.rows != 1 { print("FAIL d rows"); fail = fail + 1; };
    // Distance to nearest = 0.
    if close_f64(tensor_f64_at(&dists, 0, 0), 0.0, eps) != 1 { print("FAIL d val"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_knn_1nn_distances_f64"); return 0; };
    print("FAIL ml_recover_knn_1nn_distances_f64");
    return 1;
}
