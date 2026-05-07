import "stdlib/rods/ml/nn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

// ml_nn_facade_smoke — exercises PyTorch-style Linear + ReLU forward from
// stdlib/rods/ml/nn_facade.nr. Self-contained. Deeper torch-parity
// (cross-entropy, AdamW, full training loops) lives in subsequent batches.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // PyTorch nn.functional.linear convention: y = x @ W^T + b.
    // x = [[1, -2]] (1x2), W = [[0.5, 1.0],[0.25, 1.5]] (2x2), b = [0.1, 0.2].
    // y[0,0] = 1*0.5 + (-2)*1.0 + 0.1 = -1.4
    // y[0,1] = 1*0.25 + (-2)*1.5 + 0.2 = -2.55
    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(0.0 - 2.0);
    let x: TensorF64 = tensor_f64_from_vec(1, 2, xd);

    let mut wd: Vec<f64> = Vec::new();
    wd.push(0.5); wd.push(1.0);
    wd.push(0.25); wd.push(1.5);
    let w: TensorF64 = tensor_f64_from_vec(2, 2, wd);

    let mut bd: Vec<f64> = Vec::new();
    bd.push(0.1); bd.push(0.2);
    let b: TensorF64 = tensor_f64_from_vec(1, 2, bd);

    let y: TensorF64 = nn_linear_f64(&x, &w, &b);
    if close_f64(tensor_f64_at(&y, 0, 0), 0.0 - 1.4, eps) != 1 { print("FAIL linear y0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&y, 0, 1), 0.0 - 2.55, eps) != 1 { print("FAIL linear y1"); fail = fail + 1; };

    // ReLU clips negatives to zero; passes positives through.
    let r: TensorF64 = nn_relu_f64(&y);
    if close_f64(tensor_f64_at(&r, 0, 0), 0.0, eps) != 1 { print("FAIL relu neg0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 0, 1), 0.0, eps) != 1 { print("FAIL relu neg1"); fail = fail + 1; };

    let mut pd: Vec<f64> = Vec::new();
    pd.push(0.0 - 1.0); pd.push(0.0); pd.push(2.5);
    let p: TensorF64 = tensor_f64_from_vec(1, 3, pd);
    let pr: TensorF64 = nn_relu_f64(&p);
    if close_f64(tensor_f64_at(&pr, 0, 0), 0.0, eps) != 1 { print("FAIL relu pos -1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&pr, 0, 1), 0.0, eps) != 1 { print("FAIL relu pos 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&pr, 0, 2), 2.5, eps) != 1 { print("FAIL relu pos 2.5"); fail = fail + 1; };

    let manifest: ParityManifest = parity_manifest(
        "ml_nn_facade_smoke",
        "internal",
        "stdlib::rods::ml::nn_facade",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        1,
        2,
        eps
    );
    parity_manifest_print(&manifest);

    if fail == 0 {
        print("OK ml_nn_facade_smoke");
        return 0;
    };
    print("FAIL ml_nn_facade_smoke");
    return 1;
}
