// =====================================================
// rods/ridge — Ridge Regression (Gradient Descent)
// =====================================================
// Pure Nucleor implementation. No Python, no Tensor type.
// Uses flat Vec<f64> for matrix operations.
//
// Import: import "stdlib/rods/ridge.nr"
// Depends: complex.nr (for f64_* functions)
// =====================================================

import "stdlib/rods/complex.nr"

// --- Flat Matrix Operations ---
// Matrix stored as Vec of f64 values, row-major: M[i][j] = vec[i * cols + j]

fn mat_get(m: i64, cols: i64, r: i64, c: i64) -> i64 {
    return vec_get(m, r * cols + c);
}

fn mat_set(m: i64, cols: i64, r: i64, c: i64, val: i64) {
    vec_set(m, r * cols + c, val);
}

fn mat_new(rows: i64, cols: i64) -> i64 {
    let m: i64 = vec_new();
    let zero: i64 = f64_from_int(0);
    let mut i: i64 = 0;
    while i < rows * cols { vec_push(m, zero); i = i + 1; };
    return m;
}

// --- Ridge Training (Gradient Descent) ---
// X: flat matrix [n_samples x n_feats]
// y: Vec of n_samples target values (f64)
// Returns: Vec with [weights(n_feats), mu(n_feats), sigma(n_feats)]

fn ridge_train(X: i64, y: i64, n_samples: i64, n_feats: i64, lambda: i64, lr: i64, epochs: i64) -> i64 {
    let zero: i64 = f64_from_int(0);
    let one: i64 = f64_from_int(1);
    let tiny: i64 = f64_div(one, f64_from_int(10000000));

    // Compute per-feature mean and std
    let mu: i64 = vec_new();
    let sigma: i64 = vec_new();
    let mut f: i64 = 0;
    while f < n_feats {
        let mut s: i64 = zero;
        let mut i: i64 = 0;
        while i < n_samples {
            s = f64_add(s, mat_get(X, n_feats, i, f));
            i = i + 1;
        };
        let m: i64 = f64_div(s, f64_from_int(n_samples));
        vec_push(mu, m);

        let mut vs: i64 = zero;
        i = 0;
        while i < n_samples {
            let d: i64 = f64_sub(mat_get(X, n_feats, i, f), m);
            vs = f64_add(vs, f64_mul(d, d));
            i = i + 1;
        };
        vec_push(sigma, f64_add(f64_sqrt(f64_div(vs, f64_from_int(n_samples))), tiny));
        f = f + 1;
    };

    // Initialize weights to zero
    let weights: i64 = vec_new();
    f = 0;
    while f < n_feats { vec_push(weights, zero); f = f + 1; };

    let fn_samp: i64 = f64_from_int(n_samples);

    // Gradient descent
    let mut epoch: i64 = 0;
    while epoch < epochs {
        // Compute gradient
        let grad: i64 = vec_new();
        f = 0;
        while f < n_feats { vec_push(grad, zero); f = f + 1; };

        let mut i: i64 = 0;
        while i < n_samples {
            // Predict: dot(w, standardized x)
            let mut pred: i64 = zero;
            f = 0;
            while f < n_feats {
                let x_std: i64 = f64_div(f64_sub(mat_get(X, n_feats, i, f), vec_get(mu, f)), vec_get(sigma, f));
                pred = f64_add(pred, f64_mul(vec_get(weights, f), x_std));
                f = f + 1;
            };

            // Error
            let err: i64 = f64_sub(pred, vec_get(y, i));

            // Accumulate gradient
            f = 0;
            while f < n_feats {
                let x_std: i64 = f64_div(f64_sub(mat_get(X, n_feats, i, f), vec_get(mu, f)), vec_get(sigma, f));
                vec_set(grad, f, f64_add(vec_get(grad, f), f64_mul(err, x_std)));
                f = f + 1;
            };
            i = i + 1;
        };

        // Update: w -= lr * (grad/n + lambda*w)
        f = 0;
        while f < n_feats {
            let g: i64 = f64_add(f64_div(vec_get(grad, f), fn_samp), f64_mul(lambda, vec_get(weights, f)));
            vec_set(weights, f, f64_sub(vec_get(weights, f), f64_mul(lr, g)));
            f = f + 1;
        };
        epoch = epoch + 1;
    };

    // Pack result: [weights..., mu..., sigma...]
    let result: i64 = vec_new();
    vec_push(result, weights);
    vec_push(result, mu);
    vec_push(result, sigma);
    return result;
}

// --- Ridge Predict (single sample) ---
fn ridge_predict_one(model: i64, X: i64, n_feats: i64, idx: i64) -> i64 {
    let weights: i64 = vec_get(model, 0);
    let mu: i64 = vec_get(model, 1);
    let sigma: i64 = vec_get(model, 2);
    let zero: i64 = f64_from_int(0);
    let one: i64 = f64_from_int(1);

    let mut pred: i64 = zero;
    let mut f: i64 = 0;
    while f < n_feats {
        let x_std: i64 = f64_div(f64_sub(mat_get(X, n_feats, idx, f), vec_get(mu, f)), vec_get(sigma, f));
        pred = f64_add(pred, f64_mul(vec_get(weights, f), x_std));
        f = f + 1;
    };

    // Clip to [0, 1]
    if f64_lt(pred, zero) == 1 { pred = zero; };
    if f64_gt(pred, one) == 1 { pred = one; };
    return pred;
}

// --- MAE Computation ---
fn compute_mae(predictions: i64, actuals: i64, n: i64) -> i64 {
    let mut sum: i64 = f64_from_int(0);
    let mut i: i64 = 0;
    while i < n {
        sum = f64_add(sum, f64_abs(f64_sub(vec_get(predictions, i), vec_get(actuals, i))));
        i = i + 1;
    };
    return f64_div(sum, f64_from_int(n));
}

// --- K-Fold Cross-Validation ---
// Returns MAE averaged across k folds
fn ridge_cv(X: i64, y: i64, n_samples: i64, n_feats: i64, k_folds: i64, lambda: i64, lr: i64, epochs: i64) -> i64 {
    let fold_size: i64 = n_samples / k_folds;
    let mut total_mae: i64 = f64_from_int(0);
    let zero: i64 = f64_from_int(0);

    let mut fold: i64 = 0;
    while fold < k_folds {
        let test_start: i64 = fold * fold_size;
        let mut test_end: i64 = test_start + fold_size;
        if fold == k_folds - 1 { test_end = n_samples; };

        // Build train set (exclude test fold)
        let X_train: i64 = vec_new();
        let y_train: i64 = vec_new();
        let mut n_train: i64 = 0;
        let mut i: i64 = 0;
        while i < n_samples {
            if i < test_start || i >= test_end {
                let mut f: i64 = 0;
                while f < n_feats {
                    vec_push(X_train, mat_get(X, n_feats, i, f));
                    f = f + 1;
                };
                vec_push(y_train, vec_get(y, i));
                n_train = n_train + 1;
            };
            i = i + 1;
        };

        // Train
        let model: i64 = ridge_train(X_train, y_train, n_train, n_feats, lambda, lr, epochs);

        // Predict test fold
        let preds: i64 = vec_new();
        let actuals: i64 = vec_new();
        let mut n_test: i64 = 0;
        i = test_start;
        while i < test_end {
            // Build single-sample X for prediction
            let pred: i64 = ridge_predict_one(model, X, n_feats, i);
            vec_push(preds, pred);
            vec_push(actuals, vec_get(y, i));
            n_test = n_test + 1;
            i = i + 1;
        };

        let fold_mae: i64 = compute_mae(preds, actuals, n_test);
        total_mae = f64_add(total_mae, fold_mae);
        fold = fold + 1;
    };

    return f64_div(total_mae, f64_from_int(k_folds));
}
