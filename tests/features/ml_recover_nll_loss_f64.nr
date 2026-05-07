import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_nll_loss_f64 — scalar NLL loss over class-index targets.
// log_probs (2x3), targets [1, 2]: NLL = -mean(log_probs[i, target[i]]).
// log_probs row 0 = [-0.5, -0.3, -0.2] → -log_probs[0,1] = 0.3
// log_probs row 1 = [-1.0, -0.5, -0.1] → -log_probs[1,2] = 0.1
// mean = 0.2.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.0001;

    let mut lpd: Vec<f64> = Vec::new();
    lpd.push(0.0 - 0.5); lpd.push(0.0 - 0.3); lpd.push(0.0 - 0.2);
    lpd.push(0.0 - 1.0); lpd.push(0.0 - 0.5); lpd.push(0.0 - 0.1);
    let log_probs: TensorF64 = tensor_f64_from_vec(2, 3, lpd);

    let mut td: Vec<i64> = Vec::new();
    td.push(1); td.push(2);
    let target: TensorI64 = tensor_i64_from_vec(2, 1, td);

    let loss: f64 = nn_nll_loss_f64(&log_probs, &target);
    if close_f64(loss, 0.2, eps) != 1 { print("FAIL nll"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_nll_loss_f64"); return 0; };
    print("FAIL ml_recover_nll_loss_f64");
    return 1;
}
