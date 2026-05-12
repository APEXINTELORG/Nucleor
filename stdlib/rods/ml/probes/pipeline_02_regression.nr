import "stdlib/rods/ml/learn_facade.nr"

// PROBE-2 pipeline 02 — LinearRegression on a 12-row 3-feature CSV.
// Nucleor side: consume the pre-fitted LinearRegression params (coef +
// intercept from tests/reference/ml/02_regression.json `params` section)
// and the holdout x_test (`holdout` section), run linear_model_f64_predict,
// emit deterministic plain-text output.
//
// Per-fixture parity contract: byte-equal-to-Python parity is on the
// PREDICT step. Fit happens Python-side; Nucleor
// consumes the fitted params and reproduces predict output.
//
// Reference: tests/reference/ml/02_regression.py / .json
// Reference versions: Python 3.11.9, numpy 2.2.6, scikit-learn 1.8.0.
//
// Acceptance: this probe's stdout y_pred values match the reference's
// y_pred values within parity-manifest tolerance (default 1e-6 abs).
// Note that LinearRegression predictions are deterministic floats, so
// f64 emit precision matters.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    // --- Fitted params from 02_regression.json `params` ---
    // weights shape (3, 1), bias scalar.
    let mut wd: Vec<f64> = Vec::new();
    wd.push(1.7554508856682767);
    wd.push(3.1541384863123993);
    wd.push(0.0 - 1.6417310789049915);
    let weights: TensorF64 = tensor_f64_from_vec(3, 1, wd);

    let bias: f64 = 4.241900161030598;
    let model: LinearModelF64 = linear_model_f64(weights, bias);

    // --- Holdout x_test from 02_regression.json `holdout` ---
    let mut xd: Vec<f64> = Vec::new();
    xd.push(2.0); xd.push(4.0); xd.push(3.0);
    xd.push(4.0); xd.push(3.0); xd.push(2.0);
    xd.push(1.0); xd.push(2.0); xd.push(1.0);
    xd.push(1.0); xd.push(1.0); xd.push(1.0);
    let x_test: TensorF64 = tensor_f64_from_vec(4, 3, xd);

    // y_test (continuous targets) from reference for tolerance check
    // (not used for byte-equal comparison directly; verify hook handles
    // numeric tolerance against the reference y_pred field).
    let mut yd: Vec<f64> = Vec::new();
    yd.push(14.04); yd.push(18.02); yd.push(9.97); yd.push(8.99);

    // --- Predict ---
    let y_pred: TensorF64 = linear_model_f64_predict(&model, &x_test);

    // --- Emit deterministic structured output ---
    print("PROBE-2 case: 02_regression");
    print("n_test: 4");
    print("y_pred:");

    // Tolerance gate against the reference's y_pred values (1e-6 abs).
    // This acts as a self-check; the verify hook still cross-references
    // the reference JSON.
    let mut ref_y_pred: Vec<f64> = Vec::new();
    ref_y_pred.push(15.444162640901775);
    ref_y_pred.push(17.44265700483092);
    ref_y_pred.push(10.663896940418683);
    ref_y_pred.push(7.509758454106283);

    let eps: f64 = 0.000001;
    let mut close_count: i64 = 0;
    let mut r: i64 = 0;
    while r < y_pred.shape.rows {
        let v: f64 = tensor_f64_at(&y_pred, r, 0);
        print_f64(v);
        if close_f64(v, ref_y_pred[r], eps) == 1 {
            close_count = close_count + 1;
        };
        r = r + 1;
    };

    print("close_count_vs_reference:");
    print_int(close_count);
    print("close_count_total:");
    print_int(4);

    return 0;
}
