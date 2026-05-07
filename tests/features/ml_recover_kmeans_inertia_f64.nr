import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_kmeans_inertia_f64 — scalar inertia (sum of squared
// distances to nearest center). 2 centers at (0,0) and (10,10);
// data {(0,0), (10,10)} → inertia = 0.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut cd: Vec<f64> = Vec::new();
    cd.push(0.0); cd.push(0.0);
    cd.push(10.0); cd.push(10.0);
    let centers: TensorF64 = tensor_f64_from_vec(2, 2, cd);

    let model: KMeansF64 = kmeans_f64(centers);

    // Two perfectly-on-center points → inertia = 0.
    let mut xd: Vec<f64> = Vec::new();
    xd.push(0.0); xd.push(0.0);
    xd.push(10.0); xd.push(10.0);
    let x: TensorF64 = tensor_f64_from_vec(2, 2, xd);

    let inertia: f64 = kmeans_f64_inertia(&model, &x);
    if close_f64(inertia, 0.0, eps) != 1 { print("FAIL inertia 0"); fail = fail + 1; };

    // Off-center point: (3, 4) is sqrt(25)=5 from (0,0), much closer than to (10,10).
    let mut xd2: Vec<f64> = Vec::new();
    xd2.push(3.0); xd2.push(4.0);
    let x2: TensorF64 = tensor_f64_from_vec(1, 2, xd2);

    let inertia2: f64 = kmeans_f64_inertia(&model, &x2);
    if close_f64(inertia2, 25.0, eps) != 1 { print("FAIL inertia 25"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_kmeans_inertia_f64"); return 0; };
    print("FAIL ml_recover_kmeans_inertia_f64");
    return 1;
}
