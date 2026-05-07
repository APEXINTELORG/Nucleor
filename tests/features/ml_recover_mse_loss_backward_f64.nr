import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_mse_loss_backward_f64 — single-pass gradient:
// d(mse)/d(input) = 2*(input - target) / N. For input=[2,4], target=[1,1], N=2:
// grad = [(2-1)/1, (4-1)/1] = [1, 3]. (Reduction may scale by 2/N or just be diff.)

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut id: Vec<f64> = Vec::new();
    id.push(2.0); id.push(4.0);
    let input: TensorF64 = tensor_f64_from_vec(1, 2, id);

    let mut td: Vec<f64> = Vec::new();
    td.push(1.0); td.push(1.0);
    let target: TensorF64 = tensor_f64_from_vec(1, 2, td);

    let g: TensorF64 = nn_mse_loss_backward_f64(&input, &target);
    if g.shape.cols != 2 { print("FAIL g cols"); fail = fail + 1; };

    // Sign check: input > target → positive grad.
    if tensor_f64_at(&g, 0, 0) <= 0.0 { print("FAIL g0 sign"); fail = fail + 1; };
    if tensor_f64_at(&g, 0, 1) <= 0.0 { print("FAIL g1 sign"); fail = fail + 1; };
    // Ratio: g[1] should be ~3x g[0] (since (4-1)/(2-1) = 3).
    let ratio: f64 = tensor_f64_at(&g, 0, 1) / tensor_f64_at(&g, 0, 0);
    if close_f64(ratio, 3.0, 0.01) != 1 { print("FAIL g ratio"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_mse_loss_backward_f64"); return 0; };
    print("FAIL ml_recover_mse_loss_backward_f64");
    return 1;
}
