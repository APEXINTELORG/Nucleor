import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_pca_transform_f64 — minimal PCA transform smoke (deferred
// in ML-9 §3). 1D PCA: components is a single principal axis.
// Hand-roll components = [[1, 0]] (identity along x), mean = [0, 0].
// Transform should project (3, 4) onto x-axis = 3.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    let mut cd: Vec<f64> = Vec::new();
    cd.push(1.0); cd.push(0.0);
    let components: TensorF64 = tensor_f64_from_vec(1, 2, cd);

    let mut md: Vec<f64> = Vec::new();
    md.push(0.0); md.push(0.0);
    let mean: TensorF64 = tensor_f64_from_vec(1, 2, md);

    let model: PcaF64 = pca_f64(components, mean);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(3.0); xd.push(4.0);
    let x: TensorF64 = tensor_f64_from_vec(1, 2, xd);

    let z: TensorF64 = pca_f64_transform(&model, &x);
    if z.shape.cols != 1 { print("FAIL pca cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&z, 0, 0), 3.0, eps) != 1 { print("FAIL pca proj"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_pca_transform_f64"); return 0; };
    print("FAIL ml_recover_pca_transform_f64");
    return 1;
}
