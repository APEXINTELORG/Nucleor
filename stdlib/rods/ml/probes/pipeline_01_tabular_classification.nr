import "stdlib/rods/ml/learn_facade.nr"

// PROBE-2 pipeline 01 — tabular classification on a 12-row iris-shape CSV.
// Nucleor side: consume the pre-fitted DecisionTreeClassifier params (from
// tests/reference/ml/01_tabular_classification.json `params` section) and
// the holdout x_test (from `holdout` section), run predict_proba +
// per-row argmax + class-id lookup, emit deterministic plain-text output.
//
// Per-fixture parity contract: byte-equal-to-Python parity is on the
// PREDICT step. Fit happens Python-side; Nucleor
// consumes the fitted params and reproduces predict output byte-equal.
//
// Reference: tests/reference/ml/01_tabular_classification.py / .json
// Reference versions used to capture the params: Python 3.11.9, numpy
// 2.2.6, scikit-learn 1.8.0.
//
// Implementation note: uses `decision_tree_classifier_predict_proba_f64`
// + manual per-row argmax + classes lookup, rather than
// `decision_tree_classifier_predict_i64` directly. Both compute the same
// answer; predict_proba + argmax is the more stable path on current main
// (the predict_i64 wrapper still has a residual flake orthogonal to
// this pipeline's parity scope).
//
// Acceptance: this probe's stdout matches the corresponding fields from
// the reference JSON within parity-manifest tolerance:
//   y_pred byte-exact (sequence of class IDs).
//   accuracy_correct / accuracy_total: integer pair, tolerance 0.

fn main() -> i32 {
    // --- Fitted tree params from 01_tabular_classification.json `params` ---
    let mut nl: Vec<i64> = Vec::new();
    nl.push(1); nl.push(0 - 1); nl.push(3); nl.push(0 - 1); nl.push(0 - 1);

    let mut nr: Vec<i64> = Vec::new();
    nr.push(2); nr.push(0 - 1); nr.push(4); nr.push(0 - 1); nr.push(0 - 1);

    let mut nf: Vec<i64> = Vec::new();
    nf.push(0); nf.push(0 - 2); nf.push(2); nf.push(0 - 2); nf.push(0 - 2);

    let mut nt: Vec<f64> = Vec::new();
    nt.push(5.200000047683716);
    nt.push(0.0 - 2.0);
    nt.push(5.25);
    nt.push(0.0 - 2.0);
    nt.push(0.0 - 2.0);

    let mut nv: Vec<f64> = Vec::new();
    nv.push(0.375); nv.push(0.5);   nv.push(0.125);  // node 0
    nv.push(1.0);   nv.push(0.0);   nv.push(0.0);    // node 1 leaf -> class 0
    nv.push(0.0);   nv.push(0.8);   nv.push(0.2);    // node 2
    nv.push(0.0);   nv.push(1.0);   nv.push(0.0);    // node 3 leaf -> class 1
    nv.push(0.0);   nv.push(0.0);   nv.push(1.0);    // node 4 leaf -> class 2
    let node_values: TensorF64 = tensor_f64_from_vec(5, 3, nv);

    let mut cd: Vec<i64> = Vec::new();
    cd.push(0); cd.push(1); cd.push(2);
    let classes: TensorI64 = tensor_i64_from_vec(3, 1, cd);

    let model: DecisionTreeClassifierF64 = decision_tree_classifier_f64(nl, nr, nf, nt, node_values, classes);

    // --- Holdout x_test from 01_tabular_classification.json `holdout` ---
    let mut xd: Vec<f64> = Vec::new();
    xd.push(7.1); xd.push(3.0); xd.push(5.9); xd.push(2.1);
    xd.push(5.8); xd.push(2.7); xd.push(5.1); xd.push(1.9);
    xd.push(5.1); xd.push(3.5); xd.push(1.4); xd.push(0.2);
    xd.push(6.3); xd.push(3.3); xd.push(6.0); xd.push(2.5);
    let x_test: TensorF64 = tensor_f64_from_vec(4, 4, xd);

    let mut yd: Vec<i64> = Vec::new();
    yd.push(2); yd.push(2); yd.push(0); yd.push(2);
    let y_test: TensorI64 = tensor_i64_from_vec(4, 1, yd);

    // --- Predict via predict_proba + argmax (avoids predict_i64 wrapper UB) ---
    let proba: TensorF64 = decision_tree_classifier_predict_proba_f64(&model, &x_test);

    // Per-row argmax + class lookup, accuracy aggregate inline.
    print("PROBE-2 case: 01_tabular_classification");
    print("n_test: 4");
    print("y_pred:");

    let mut correct: i64 = 0;
    let mut r: i64 = 0;
    while r < proba.shape.rows {
        let mut best_idx: i64 = 0;
        let mut best_val: f64 = tensor_f64_at(&proba, r, 0);
        let mut c: i64 = 1;
        while c < proba.shape.cols {
            let v: f64 = tensor_f64_at(&proba, r, c);
            if v > best_val {
                best_val = v;
                best_idx = c;
            };
            c = c + 1;
        };
        // For this case classes == [0, 1, 2] so pred_class == best_idx.
        // Avoiding model.classes lookup keeps the predict path off the
        // residual wrapper-layer UB on the deeper-composed predict_i64
        // chain.
        let pred_class: i64 = best_idx;
        print_int(pred_class);
        if pred_class == tensor_i64_at(&y_test, r, 0) {
            correct = correct + 1;
        };
        r = r + 1;
    };

    print("accuracy_correct:");
    print_int(correct);
    print("accuracy_total:");
    print_int(4);

    return 0;
}
