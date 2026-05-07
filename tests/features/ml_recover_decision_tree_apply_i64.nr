import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_decision_tree_apply_i64 — fitted decision tree leaf
// indices via single-pass tree walk. Build a tiny 3-node tree:
// node 0 (internal): feature 0, threshold 0.5 → left=1, right=2
// node 1 (leaf): class 0
// node 2 (leaf): class 1
// Query [0.0] → leaf 1; query [1.0] → leaf 2.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let mut nl: Vec<i64> = Vec::new();
    nl.push(1); nl.push(0 - 1); nl.push(0 - 1);
    let mut nr: Vec<i64> = Vec::new();
    nr.push(2); nr.push(0 - 1); nr.push(0 - 1);
    let mut nf: Vec<i64> = Vec::new();
    nf.push(0); nf.push(0 - 1); nf.push(0 - 1);
    let mut nt: Vec<f64> = Vec::new();
    nt.push(0.5); nt.push(0.0); nt.push(0.0);

    // node_values: per-node class distributions (3 nodes × 2 classes).
    let mut nv: Vec<f64> = Vec::new();
    nv.push(1.0); nv.push(1.0);   // node 0 mixed
    nv.push(1.0); nv.push(0.0);   // node 1 pure class 0
    nv.push(0.0); nv.push(1.0);   // node 2 pure class 1
    let node_values: TensorF64 = tensor_f64_from_vec(3, 2, nv);

    let mut cd: Vec<i64> = Vec::new();
    cd.push(0); cd.push(1);
    let classes: TensorI64 = tensor_i64_from_vec(2, 1, cd);

    let model: DecisionTreeClassifierF64 = decision_tree_classifier_f64(nl, nr, nf, nt, node_values, classes);

    let mut qd: Vec<f64> = Vec::new();
    qd.push(0.0);
    qd.push(1.0);
    let q: TensorF64 = tensor_f64_from_vec(2, 1, qd);

    let leaves: TensorI64 = decision_tree_classifier_apply_i64(&model, &q);
    if leaves.shape.rows != 2 { print("FAIL leaves rows"); fail = fail + 1; };
    if tensor_i64_at(&leaves, 0, 0) != 1 { print("FAIL leaf 0"); fail = fail + 1; };
    if tensor_i64_at(&leaves, 1, 0) != 2 { print("FAIL leaf 1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_decision_tree_apply_i64"); return 0; };
    print("FAIL ml_recover_decision_tree_apply_i64");
    return 1;
}
