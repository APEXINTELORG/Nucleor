import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_gaussian_nb_joint_log_likelihood_f64 — single forward
// joint log likelihood for fitted Gaussian NB (deferred ML-9 family).

fn main() -> i32 {
    let mut fail: i64 = 0;

    // 2 classes × 2 features. theta (means): class 0=(0,0), class 1=(5,5).
    let mut td: Vec<f64> = Vec::new();
    td.push(0.0); td.push(0.0);
    td.push(5.0); td.push(5.0);
    let theta: TensorF64 = tensor_f64_from_vec(2, 2, td);

    // var (variances): both 1.0.
    let mut vd: Vec<f64> = Vec::new();
    vd.push(1.0); vd.push(1.0);
    vd.push(1.0); vd.push(1.0);
    let var: TensorF64 = tensor_f64_from_vec(2, 2, vd);

    // Equal class priors (log 0.5 ≈ -0.693).
    let mut pd: Vec<f64> = Vec::new();
    pd.push(0.0 - 0.693); pd.push(0.0 - 0.693);
    let class_prior: TensorF64 = tensor_f64_from_vec(2, 1, pd);

    let mut cd: Vec<i64> = Vec::new();
    cd.push(0); cd.push(1);
    let classes: TensorI64 = tensor_i64_from_vec(2, 1, cd);

    let model: GaussianNBF64 = gaussian_nb_f64(theta, var, class_prior, classes);

    // Query (0.1, 0.1) → much closer to class 0 mean → larger log-likelihood for class 0.
    let mut xd: Vec<f64> = Vec::new();
    xd.push(0.1); xd.push(0.1);
    let x: TensorF64 = tensor_f64_from_vec(1, 2, xd);

    let jll: TensorF64 = gaussian_nb_joint_log_likelihood_f64(&model, &x);
    if jll.shape.cols != 2 { print("FAIL jll cols"); fail = fail + 1; };

    let l0: f64 = tensor_f64_at(&jll, 0, 0);
    let l1: f64 = tensor_f64_at(&jll, 0, 1);
    // Class 0 likelihood should be higher (less negative).
    if l0 <= l1 { print("FAIL jll class 0 not dominant"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_gaussian_nb_joint_log_likelihood_f64"); return 0; };
    print("FAIL ml_recover_gaussian_nb_joint_log_likelihood_f64");
    return 1;
}
