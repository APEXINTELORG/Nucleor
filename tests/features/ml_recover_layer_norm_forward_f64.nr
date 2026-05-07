import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_layer_norm_forward_f64 — minimal LayerNorm forward smoke
// (deferred in ML-10 §3). 1×3 row [1, 2, 3]: mean=2, var=2/3, std=sqrt(2/3).
// LayerNorm with weight=[1,1,1], bias=[0,0,0] outputs (x-mean)/std =
// [-sqrt(1.5), 0, sqrt(1.5)] approximately [-1.2247, 0, 1.2247].

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(2.0); xd.push(3.0);
    let x: TensorF64 = tensor_f64_from_vec(1, 3, xd);

    let mut wd: Vec<f64> = Vec::new();
    wd.push(1.0); wd.push(1.0); wd.push(1.0);
    let w: TensorF64 = tensor_f64_from_vec(1, 3, wd);

    let mut bd: Vec<f64> = Vec::new();
    bd.push(0.0); bd.push(0.0); bd.push(0.0);
    let b: TensorF64 = tensor_f64_from_vec(1, 3, bd);

    let y: TensorF64 = nn_layer_norm_f64(&x, &w, &b, 0.00001);
    if y.shape.rows != 1 { print("FAIL ln rows"); fail = fail + 1; };
    if y.shape.cols != 3 { print("FAIL ln cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&y, 0, 1), 0.0, eps) != 1 { print("FAIL ln middle"); fail = fail + 1; };

    // Output should be antisymmetric around the middle.
    let l: f64 = tensor_f64_at(&y, 0, 0);
    let r: f64 = tensor_f64_at(&y, 0, 2);
    if close_f64(l + r, 0.0, eps) != 1 { print("FAIL ln antisymm"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_layer_norm_forward_f64"); return 0; };
    print("FAIL ml_recover_layer_norm_forward_f64");
    return 1;
}
