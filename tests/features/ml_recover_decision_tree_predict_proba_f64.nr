import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_decision_tree_predict_proba_f64 — predict_proba returns
// per-class probabilities (normalized class-counts at the leaf).

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut nl: Vec<i64> = Vec::new();
    nl.push(1); nl.push(0 - 1); nl.push(0 - 1);
    let mut nr: Vec<i64> = Vec::new();
    nr.push(2); nr.push(0 - 1); nr.push(0 - 1);
    let mut nf: Vec<i64> = Vec::new();
    nf.push(0); nf.push(0 - 1); nf.push(0 - 1);
    let mut nt: Vec<f64> = Vec::new();
    nt.push(0.5); nt.push(0.0); nt.push(0.0);

    let mut nv: Vec<f64> = Vec::new();
    nv.push(1.0); nv.push(1.0);   // node 0 (unused; internal)
    nv.push(8.0); nv.push(2.0);   // node 1 leaf: 8 of class 0, 2 of class 1 → prob [0.8, 0.2]
    nv.push(1.0); nv.push(9.0);   // node 2 leaf: 1 of class 0, 9 of class 1 → prob [0.1, 0.9]
    let node_values: TensorF64 = tensor_f64_from_vec(3, 2, nv);

    let mut cd: Vec<i64> = Vec::new();
    cd.push(0); cd.push(1);
    let classes: TensorI64 = tensor_i64_from_vec(2, 1, cd);

    let model: DecisionTreeClassifierF64 = decision_tree_classifier_f64(nl, nr, nf, nt, node_values, classes);

    let mut qd: Vec<f64> = Vec::new();
    qd.push(0.0);   // → leaf 1
    qd.push(1.0);   // → leaf 2
    let q: TensorF64 = tensor_f64_from_vec(2, 1, qd);

    let p: TensorF64 = decision_tree_classifier_predict_proba_f64(&model, &q);
    if p.shape.rows != 2 { print("FAIL p rows"); fail = fail + 1; };
    if p.shape.cols != 2 { print("FAIL p cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&p, 0, 0), 0.8, eps) != 1 { print("FAIL p 00"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&p, 0, 1), 0.2, eps) != 1 { print("FAIL p 01"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&p, 1, 0), 0.1, eps) != 1 { print("FAIL p 10"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&p, 1, 1), 0.9, eps) != 1 { print("FAIL p 11"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_decision_tree_predict_proba_f64"); return 0; };
    print("FAIL ml_recover_decision_tree_predict_proba_f64");
    return 1;
}
