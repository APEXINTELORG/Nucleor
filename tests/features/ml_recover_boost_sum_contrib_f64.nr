import "stdlib/rods/ml/boost_facade.nr"

// ml_recover_boost_sum_contrib_f64 — sum per-stump contributions across
// rows. Input contribs is a (rows × stumps) matrix; output is (rows × 1)
// summed contribution per row.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // 3 rows × 2 stumps. Row 0: [0.1, 0.2] = 0.3. Row 1: [0.5, -0.5] = 0.0. Row 2: [1.0, 1.0] = 2.0.
    let mut cd: Vec<f64> = Vec::new();
    cd.push(0.1); cd.push(0.2);
    cd.push(0.5); cd.push(0.0 - 0.5);
    cd.push(1.0); cd.push(1.0);
    let contribs: TensorF64 = tensor_f64_from_vec(3, 2, cd);

    let s: TensorF64 = boost_stump_ensemble_sum_contrib_f64(&contribs);
    if s.shape.rows != 3 { print("FAIL s rows"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&s, 0, 0), 0.3, eps) != 1 { print("FAIL s 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&s, 1, 0), 0.0, eps) != 1 { print("FAIL s 1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&s, 2, 0), 2.0, eps) != 1 { print("FAIL s 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_boost_sum_contrib_f64"); return 0; };
    print("FAIL ml_recover_boost_sum_contrib_f64");
    return 1;
}
