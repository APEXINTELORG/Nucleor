import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_knn_1nn_indices_i64 — nearest-neighbor index only, no
// label lookup or distance metric.

fn main() -> i32 {
    let mut fail: i64 = 0;

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

    let mut qd: Vec<f64> = Vec::new();
    qd.push(3.0); qd.push(4.0);
    let q: TensorF64 = tensor_f64_from_vec(1, 2, qd);

    let idx: TensorI64 = knn_1nn_indices_i64(&model, &q);
    if idx.shape.rows != 1 { print("FAIL idx rows"); fail = fail + 1; };
    // Nearest training row to (3,4) is index 1.
    if tensor_i64_at(&idx, 0, 0) != 1 { print("FAIL idx val"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_knn_1nn_indices_i64"); return 0; };
    print("FAIL ml_recover_knn_1nn_indices_i64");
    return 1;
}
