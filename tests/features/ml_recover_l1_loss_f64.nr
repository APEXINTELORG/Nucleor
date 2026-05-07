import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_l1_loss_f64 — scalar L1 (mean absolute error) loss.
// input=[1,2,3], target=[2,4,6]: |diffs| = [1,2,3], mean = 2.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    let mut id: Vec<f64> = Vec::new();
    id.push(1.0); id.push(2.0); id.push(3.0);
    let input: TensorF64 = tensor_f64_from_vec(1, 3, id);

    let mut td: Vec<f64> = Vec::new();
    td.push(2.0); td.push(4.0); td.push(6.0);
    let target: TensorF64 = tensor_f64_from_vec(1, 3, td);

    let loss: f64 = nn_l1_loss_f64(&input, &target);
    if close_f64(loss, 2.0, eps) != 1 { print("FAIL l1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_l1_loss_f64"); return 0; };
    print("FAIL ml_recover_l1_loss_f64");
    return 1;
}
