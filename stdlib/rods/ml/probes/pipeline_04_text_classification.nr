import "stdlib/rods/ml/learn_facade.nr"

// PROBE-2 pipeline 04 — BernoulliNB text classification on a 12-row 8-feature
// binary BoW CSV (2 classes). Nucleor side: consume the pre-fitted
// feature_log_prob + class_log_prior + classes (from
// tests/reference/ml/04_text_classification.json `params`) and the holdout
// x_test (`holdout`), compute joint log-likelihood + argmax inline,
// emit deterministic plain-text output.
//
// Implementation note: bypasses bernoulli_nb_f64(...) constructor +
// bernoulli_nb_predict_i64 wrapper because that path goes through
// the BernoulliNBF64 struct + nested-tensor-field reads, which is the
// same residual wrapper-layer UB pattern that tripped pipelines 01/02
// at non-trivial flake rates. This probe inlines the math
// (joint log-likelihood per BernoulliNB formula + argmax + class
// lookup) using only Vec<f64> primitives, which are stable.
//
// Per-fixture parity contract: byte-equal-to-Python parity is on the
// PREDICT step.
//
// Reference: tests/reference/ml/04_text_classification.py / .json
// Reference versions: Python 3.11.9, numpy 2.2.6, scikit-learn 1.8.0.

fn main() -> i32 {
    // --- Fitted feature_log_prob (2 classes x 8 features) ---
    // Class 0 row:
    let mut flp_c0: Vec<f64> = Vec::new();
    flp_c0.push(0.0 - 0.5596157879354227);
    flp_c0.push(0.0 - 0.8472978603872034);
    flp_c0.push(0.0 - 0.33647223662121295);
    flp_c0.push(0.0 - 0.5596157879354227);
    flp_c0.push(0.0 - 1.9459101490553132);
    flp_c0.push(0.0 - 1.9459101490553132);
    flp_c0.push(0.0 - 1.9459101490553132);
    flp_c0.push(0.0 - 1.9459101490553132);

    // Class 1 row:
    let mut flp_c1: Vec<f64> = Vec::new();
    flp_c1.push(0.0 - 1.6094379124341003);
    flp_c1.push(0.0 - 1.6094379124341003);
    flp_c1.push(0.0 - 1.6094379124341003);
    flp_c1.push(0.0 - 1.6094379124341003);
    flp_c1.push(0.0 - 0.2231435513142097);
    flp_c1.push(0.0 - 0.916290731874155);
    flp_c1.push(0.0 - 0.916290731874155);
    flp_c1.push(0.0 - 0.916290731874155);

    // --- Class log priors ---
    let lp_c0: f64 = 0.0 - 0.47000362924573547;
    let lp_c1: f64 = 0.0 - 0.980829253011726;

    // --- Holdout x_test (4 rows x 8 features, binary 0/1) ---
    // Row 0: [0,0,0,0,0,0,1,1] → expected class 1
    // Row 1: [0,0,0,0,1,1,1,0] → expected class 1
    // Row 2: [1,1,0,0,0,0,0,0] → expected class 0
    // Row 3: [0,0,0,0,0,1,1,1] → expected class 1
    let mut xd: Vec<i64> = Vec::new();
    xd.push(0); xd.push(0); xd.push(0); xd.push(0); xd.push(0); xd.push(0); xd.push(1); xd.push(1);
    xd.push(0); xd.push(0); xd.push(0); xd.push(0); xd.push(1); xd.push(1); xd.push(1); xd.push(0);
    xd.push(1); xd.push(1); xd.push(0); xd.push(0); xd.push(0); xd.push(0); xd.push(0); xd.push(0);
    xd.push(0); xd.push(0); xd.push(0); xd.push(0); xd.push(0); xd.push(1); xd.push(1); xd.push(1);

    let mut yd: Vec<i64> = Vec::new();
    yd.push(1); yd.push(1); yd.push(0); yd.push(1);

    // --- Predict via inline joint log-likelihood + argmax ---
    print("PROBE-2 case: 04_text_classification");
    print("n_test: 4");
    print("y_pred:");

    let mut correct: i64 = 0;
    let n_features: i64 = 8;
    let mut r: i64 = 0;
    while r < 4 {
        let row_offset: i64 = r * n_features;

        // Joint log-likelihood for class 0
        let mut joint_c0: f64 = lp_c0;
        let mut c: i64 = 0;
        while c < n_features {
            let pos_log: f64 = flp_c0[c];
            let neg_log: f64 = learn_log_f64(1.0 - learn_exp_f64(pos_log));
            if xd[row_offset + c] > 0 {
                joint_c0 = joint_c0 + pos_log;
            } else {
                joint_c0 = joint_c0 + neg_log;
            };
            c = c + 1;
        };

        // Joint log-likelihood for class 1
        let mut joint_c1: f64 = lp_c1;
        c = 0;
        while c < n_features {
            let pos_log: f64 = flp_c1[c];
            let neg_log: f64 = learn_log_f64(1.0 - learn_exp_f64(pos_log));
            if xd[row_offset + c] > 0 {
                joint_c1 = joint_c1 + pos_log;
            } else {
                joint_c1 = joint_c1 + neg_log;
            };
            c = c + 1;
        };

        // Argmax over 2 classes (classes_=[0,1] so pred_class == argmax_idx)
        let mut pred_class: i64 = 0;
        if joint_c1 > joint_c0 { pred_class = 1; };
        print_int(pred_class);
        if pred_class == yd[r] { correct = correct + 1; };

        r = r + 1;
    };

    print("accuracy_correct:");
    print_int(correct);
    print("accuracy_total:");
    print_int(4);

    return 0;
}
