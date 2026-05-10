// Audit proof F-MATH-012: decision_tree_classifier_predict_i64 must be a
// stable public API path, not a documented-broken wrapper bypass.

import "stdlib/rods/ml/learn_facade.nr"

fn main() -> i64 {
    let mut left: Vec<i64> = Vec::new();
    left.push(1);
    left.push(0 - 1);
    left.push(0 - 1);

    let mut right: Vec<i64> = Vec::new();
    right.push(2);
    right.push(0 - 1);
    right.push(0 - 1);

    let mut features: Vec<i64> = Vec::new();
    features.push(0);
    features.push(0 - 1);
    features.push(0 - 1);

    let mut thresholds: Vec<f64> = Vec::new();
    thresholds.push(2.5);
    thresholds.push(0.0);
    thresholds.push(0.0);

    let mut values_data: Vec<f64> = Vec::new();
    values_data.push(0.0); values_data.push(0.0);
    values_data.push(3.0); values_data.push(0.0);
    values_data.push(0.0); values_data.push(5.0);
    let values: TensorF64 = tensor_f64_from_vec(3, 2, values_data);

    let mut class_data: Vec<i64> = Vec::new();
    class_data.push(10);
    class_data.push(20);
    let classes: TensorI64 = tensor_i64_from_vec(2, 1, class_data);

    let model: DecisionTreeClassifierF64 =
        decision_tree_classifier_f64(left, right, features, thresholds, values, classes);

    let mut x_data: Vec<f64> = Vec::new();
    x_data.push(1.0);
    x_data.push(4.0);
    let x: TensorF64 = tensor_f64_from_vec(2, 1, x_data);

    let labels: TensorI64 = decision_tree_classifier_predict_i64(&model, &x);
    if tensor_i64_len(&labels) != 2 { return 1; };
    if tensor_i64_at(&labels, 0, 0) != 10 { return 4; };
    if tensor_i64_at(&labels, 1, 0) != 20 { return 8; };
    return 0;
}
