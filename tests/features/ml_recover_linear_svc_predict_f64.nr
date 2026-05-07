import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_linear_svc_predict_f64 — minimal fitted Linear SVC smoke
// (deferred in ML-9 §3). 2-class hand-rolled w / b: w = [[1, 1]] picks
// class 0 if x0+x1 < 1.5, class 1 otherwise. (LinearSvcModelF64 uses a
// per-class weight row layout.)

fn main() -> i32 {
    let mut fail: i64 = 0;

    // 2 classes, 2 features. Per-class weight rows.
    let mut wd: Vec<f64> = Vec::new();
    wd.push(0.0 - 1.0); wd.push(0.0 - 1.0);   // class 0: -x - y > 0 means class 0
    wd.push(1.0); wd.push(1.0);                // class 1: x + y > 0 means class 1
    let weights: TensorF64 = tensor_f64_from_vec(2, 2, wd);

    let mut bd: Vec<f64> = Vec::new();
    bd.push(1.5); bd.push(0.0 - 1.5);          // class 0 bias +1.5, class 1 bias -1.5
    let bias: TensorF64 = tensor_f64_from_vec(2, 1, bd);

    let mut cd: Vec<i64> = Vec::new();
    cd.push(0); cd.push(1);
    let classes: TensorI64 = tensor_i64_from_vec(2, 1, cd);

    let model: LinearSvcModelF64 = linear_svc_model_f64(weights, bias, classes);

    // Query (0.5, 0.5): class 0 score = -1+1.5 = 0.5; class 1 score = 1-1.5 = -0.5. argmax = 0.
    // Query (2.0, 2.0): class 0 score = -4+1.5 = -2.5; class 1 score = 4-1.5 = 2.5. argmax = 1.
    let mut qd: Vec<f64> = Vec::new();
    qd.push(0.5); qd.push(0.5);
    qd.push(2.0); qd.push(2.0);
    let q: TensorF64 = tensor_f64_from_vec(2, 2, qd);

    let labels: TensorI64 = linear_svc_predict_i64(&model, &q);
    if labels.shape.rows != 2 { print("FAIL svc rows"); fail = fail + 1; };
    if tensor_i64_at(&labels, 0, 0) != 0 { print("FAIL svc label 0"); fail = fail + 1; };
    if tensor_i64_at(&labels, 1, 0) != 1 { print("FAIL svc label 1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_linear_svc_predict_f64"); return 0; };
    print("FAIL ml_recover_linear_svc_predict_f64");
    return 1;
}
