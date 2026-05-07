import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

// ml_learn_facade_smoke — exercises the linear-model predict surface from
// stdlib/rods/ml/learn_facade.nr. Specifically validates the previously-
// blocking `&raw`-on-local pattern at lines 1392+1395-99 and 1449+1452-56,
// renamed in this batch to `mv` to disambiguate from raw-pointer syntax.
// Deeper sklearn parity claims live in subsequent batches.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // X = [[1,2],[3,4]], w = [[0.5],[0.25]], b = 1.0
    // y = X @ w + b = [[0.5*1 + 0.25*2 + 1.0], [0.5*3 + 0.25*4 + 1.0]] = [[2.0], [3.5]]
    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(2.0);
    xd.push(3.0); xd.push(4.0);
    let x: TensorF64 = tensor_f64_from_vec(2, 2, xd);

    let mut wd: Vec<f64> = Vec::new();
    wd.push(0.5);
    wd.push(0.25);
    let w: TensorF64 = tensor_f64_from_vec(2, 1, wd);

    let model: LinearModelF64 = linear_model_f64(w, 1.0);
    let yhat: TensorF64 = linear_model_f64_predict(&model, &x);

    if yhat.shape.rows != 2 { print("FAIL linear rows"); fail = fail + 1; };
    if yhat.shape.cols != 1 { print("FAIL linear cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&yhat, 0, 0), 2.0, eps) != 1 { print("FAIL linear y0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&yhat, 1, 0), 3.5, eps) != 1 { print("FAIL linear y1"); fail = fail + 1; };

    // Lasso/ElasticNet predict alias the linear path.
    let yl: TensorF64 = lasso_f64_predict(&model, &x);
    if close_f64(tensor_f64_at(&yl, 0, 0), 2.0, eps) != 1 { print("FAIL lasso y0"); fail = fail + 1; };

    let ye: TensorF64 = elastic_net_f64_predict(&model, &x);
    if close_f64(tensor_f64_at(&ye, 1, 0), 3.5, eps) != 1 { print("FAIL elastic y1"); fail = fail + 1; };

    let manifest: ParityManifest = parity_manifest(
        "ml_learn_facade_smoke",
        "internal",
        "stdlib::rods::ml::learn_facade",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        2,
        eps
    );
    parity_manifest_print(&manifest);

    if fail == 0 {
        print("OK ml_learn_facade_smoke");
        return 0;
    };
    print("FAIL ml_learn_facade_smoke");
    return 1;
}
