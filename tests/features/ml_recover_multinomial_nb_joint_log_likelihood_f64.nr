import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_multinomial_nb_joint_log_likelihood_f64 — single forward
// joint log likelihood for fitted multinomial NB.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // 2 classes × 3 features. feature_log_prob: class 0 = log([0.7, 0.2, 0.1]),
    // class 1 = log([0.1, 0.2, 0.7]).
    let mut fp: Vec<f64> = Vec::new();
    fp.push(0.0 - 0.357); fp.push(0.0 - 1.609); fp.push(0.0 - 2.303);
    fp.push(0.0 - 2.303); fp.push(0.0 - 1.609); fp.push(0.0 - 0.357);
    let feature_log_prob: TensorF64 = tensor_f64_from_vec(2, 3, fp);

    let mut clp: Vec<f64> = Vec::new();
    clp.push(0.0 - 0.693); clp.push(0.0 - 0.693);  // equal class priors
    let class_log_prior: TensorF64 = tensor_f64_from_vec(2, 1, clp);

    let mut cd: Vec<i64> = Vec::new();
    cd.push(0); cd.push(1);
    let classes: TensorI64 = tensor_i64_from_vec(2, 1, cd);

    let model: MultinomialNBF64 = multinomial_nb_f64(feature_log_prob, class_log_prior, classes);

    // Query: count vector strongly matches class 0 (high count for feature 0).
    let mut xd: Vec<f64> = Vec::new();
    xd.push(10.0); xd.push(0.0); xd.push(0.0);
    let x: TensorF64 = tensor_f64_from_vec(1, 3, xd);

    let jll: TensorF64 = multinomial_nb_joint_log_likelihood_f64(&model, &x);
    if jll.shape.cols != 2 { print("FAIL jll cols"); fail = fail + 1; };

    let l0: f64 = tensor_f64_at(&jll, 0, 0);
    let l1: f64 = tensor_f64_at(&jll, 0, 1);
    // Class 0 should have much higher log likelihood for the count vector.
    if l0 <= l1 { print("FAIL class 0 not dominant"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_multinomial_nb_joint_log_likelihood_f64"); return 0; };
    print("FAIL ml_recover_multinomial_nb_joint_log_likelihood_f64");
    return 1;
}
