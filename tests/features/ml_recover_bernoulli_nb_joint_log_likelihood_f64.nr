import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_bernoulli_nb_joint_log_likelihood_f64 — Bernoulli NB
// joint log likelihood over binary feature vectors.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // 2 classes × 2 features. feature_log_prob: log P(feature=1 | class).
    // class 0 strongly likes feature 0 (high prob), class 1 likes feature 1.
    let mut fp: Vec<f64> = Vec::new();
    fp.push(0.0 - 0.105); fp.push(0.0 - 2.303);   // class 0: log(0.9), log(0.1)
    fp.push(0.0 - 2.303); fp.push(0.0 - 0.105);   // class 1: log(0.1), log(0.9)
    let feature_log_prob: TensorF64 = tensor_f64_from_vec(2, 2, fp);

    let mut clp: Vec<f64> = Vec::new();
    clp.push(0.0 - 0.693); clp.push(0.0 - 0.693);
    let class_log_prior: TensorF64 = tensor_f64_from_vec(2, 1, clp);

    let mut cd: Vec<i64> = Vec::new();
    cd.push(0); cd.push(1);
    let classes: TensorI64 = tensor_i64_from_vec(2, 1, cd);

    let model: BernoulliNBF64 = bernoulli_nb_f64(feature_log_prob, class_log_prior, classes);

    // Query [1, 0] strongly matches class 0.
    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(0.0);
    let x: TensorF64 = tensor_f64_from_vec(1, 2, xd);

    let jll: TensorF64 = bernoulli_nb_joint_log_likelihood_f64(&model, &x);
    if jll.shape.cols != 2 { print("FAIL jll cols"); fail = fail + 1; };

    let l0: f64 = tensor_f64_at(&jll, 0, 0);
    let l1: f64 = tensor_f64_at(&jll, 0, 1);
    if l0 <= l1 { print("FAIL class 0 not dominant"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_bernoulli_nb_joint_log_likelihood_f64"); return 0; };
    print("FAIL ml_recover_bernoulli_nb_joint_log_likelihood_f64");
    return 1;
}
