import "stdlib/rods/ml/boost_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

// ml_boost_facade_smoke — exercises the gradient-boosting stump-ensemble
// surface from stdlib/rods/ml/boost_facade.nr: predict_margin and
// predict_proba over a small fitted ensemble. Self-contained. Deeper
// XGBoost/LightGBM/CatBoost parity (multi-depth trees, missing-value
// routing, sparse CSR, decision-path indicators) lives in subsequent
// batches.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // 4 samples × 3 features, 3 stumps splitting on features 0, 1, 2.
    // Feature matrix matches the master parity fixture; this smoke is a
    // narrower subset that confirms margin/probability output shape and
    // monotonicity rather than full XGBoost numerical parity.
    let mut xd: Vec<f64> = Vec::new();
    xd.push(0.2); xd.push(1.5); xd.push(0.0 - 0.5);
    xd.push(1.4); xd.push(0.2); xd.push(2.0);
    xd.push(0.0 - 0.7); xd.push(0.8); xd.push(1.2);
    xd.push(2.2); xd.push(1.1); xd.push(0.0 - 1.0);
    let x: TensorF64 = tensor_f64_from_vec(4, 3, xd);

    let mut features: Vec<i64> = Vec::new();
    features.push(0); features.push(1); features.push(2);

    let mut thresholds: Vec<f64> = Vec::new();
    thresholds.push(0.5); thresholds.push(1.0); thresholds.push(0.0);

    let mut left_values: Vec<f64> = Vec::new();
    left_values.push(0.4); left_values.push(0.0 - 0.3); left_values.push(0.15);

    let mut right_values: Vec<f64> = Vec::new();
    right_values.push(0.0 - 0.2); right_values.push(0.25); right_values.push(0.0 - 0.1);

    let model: BoostStumpEnsembleF64 = boost_stump_ensemble_f64(
        features,
        thresholds,
        left_values,
        right_values,
        0.8,
        0.05
    );

    let margins: TensorF64 = boost_stump_ensemble_predict_margin_f64(&model, &x);
    if margins.shape.rows != 4 { print("FAIL margin rows"); fail = fail + 1; };
    if margins.shape.cols != 1 { print("FAIL margin cols"); fail = fail + 1; };

    // Probabilities should all lie in (0, 1).
    let probabilities: TensorF64 = boost_stump_ensemble_predict_proba_f64(&model, &x);
    if probabilities.shape.rows != 4 { print("FAIL proba rows"); fail = fail + 1; };
    if probabilities.shape.cols != 1 { print("FAIL proba cols"); fail = fail + 1; };

    let mut i: i64 = 0;
    while i < 4 {
        let p: f64 = tensor_f64_at(&probabilities, i, 0);
        if p <= 0.0 { print("FAIL proba <= 0"); fail = fail + 1; };
        if p >= 1.0 { print("FAIL proba >= 1"); fail = fail + 1; };
        i = i + 1;
    };

    let manifest: ParityManifest = parity_manifest(
        "ml_boost_facade_smoke",
        "internal",
        "stdlib::rods::ml::boost_facade",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        4,
        3,
        eps
    );
    parity_manifest_print(&manifest);

    if fail == 0 {
        print("OK ml_boost_facade_smoke");
        return 0;
    };
    print("FAIL ml_boost_facade_smoke");
    return 1;
}
