import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_gaussian_nb_predict_log_proba_f64 — log-probability output
// (no normalization to [0, 1] — just log-likelihoods normalized by
// log-sum-exp). Different code path than predict_proba which exponentiates.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let mut td: Vec<f64> = Vec::new();
    td.push(0.0); td.push(0.0);
    td.push(5.0); td.push(5.0);
    let theta: TensorF64 = tensor_f64_from_vec(2, 2, td);

    let mut vd: Vec<f64> = Vec::new();
    vd.push(1.0); vd.push(1.0);
    vd.push(1.0); vd.push(1.0);
    let var: TensorF64 = tensor_f64_from_vec(2, 2, vd);

    let mut clp: Vec<f64> = Vec::new();
    clp.push(0.0 - 0.693); clp.push(0.0 - 0.693);
    let class_prior: TensorF64 = tensor_f64_from_vec(2, 1, clp);

    let mut cd: Vec<i64> = Vec::new();
    cd.push(0); cd.push(1);
    let classes: TensorI64 = tensor_i64_from_vec(2, 1, cd);

    let model: GaussianNBF64 = gaussian_nb_f64(theta, var, class_prior, classes);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(0.1); xd.push(0.1);
    let x: TensorF64 = tensor_f64_from_vec(1, 2, xd);

    let lp: TensorF64 = gaussian_nb_predict_log_proba_f64(&model, &x);
    if lp.shape.cols != 2 { print("FAIL lp cols"); fail = fail + 1; };

    let l0: f64 = tensor_f64_at(&lp, 0, 0);
    let l1: f64 = tensor_f64_at(&lp, 0, 1);
    // Both should be negative (log probabilities), and class 0 should be greater (closer to 0).
    if l0 >= 0.0 { print("FAIL l0 not neg"); fail = fail + 1; };
    if l1 >= 0.0 { print("FAIL l1 not neg"); fail = fail + 1; };
    if l0 <= l1 { print("FAIL class 0 not dominant"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_gaussian_nb_predict_log_proba_f64"); return 0; };
    print("FAIL ml_recover_gaussian_nb_predict_log_proba_f64");
    return 1;
}
