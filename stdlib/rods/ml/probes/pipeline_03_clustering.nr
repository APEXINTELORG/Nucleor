import "stdlib/rods/ml/learn_facade.nr"

// PROBE-2 pipeline 03 — KMeans clustering on a 15-row 2-feature CSV.
// Nucleor side: consume the pre-fitted KMeans centers (from
// tests/reference/ml/03_clustering.json `params.centers`) and the same
// 15-row input data, compute per-row argmin distance, emit labels +
// cluster-size signature.
//
// Implementation note: bypasses kmeans_f64(...) constructor +
// kmeans_f64_predict wrapper because that path hits a residual
// wrapper-layer UB on current main that emits garbage labels (same
// family the structural DFLIP-PATCH didn't fully close on KMeans).
// Instead this probe builds a centers TensorF64, then per-row calls
// kmeans_f64_squared_distance_row_center directly + my own argmin,
// which is the stable path verified by the existing
// ml_recover_kmeans_squared_distance_f64 fixture.
//
// Per-fixture parity contract (see findings/inbox/
// ml_agent_probe2_design_no_fit_apis_v0846_2026-05-08.md): byte-equal-to-
// Python parity is on the PREDICT step (assignment to nearest center).
//
// IMPORTANT: KMeans cluster IDs are PERMUTATION-INVARIANT. Verify hook
// compares cluster-size signature (sorted partition sizes), not raw
// label IDs.
//
// Reference: tests/reference/ml/03_clustering.py / .json
// Reference versions: Python 3.11.9, numpy 2.2.6, scikit-learn 1.8.0.

fn main() -> i32 {
    // --- Fitted centers from 03_clustering.json `params.centers` ---
    let mut cd: Vec<f64> = Vec::new();
    cd.push(10.02); cd.push(10.0);
    cd.push(1.0199999999999996); cd.push(10.0);
    cd.push(1.0199999999999996); cd.push(1.0);
    let centers: TensorF64 = tensor_f64_from_vec(3, 2, cd);

    // --- Input data ---
    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(1.2);
    xd.push(1.2); xd.push(0.9);
    xd.push(0.8); xd.push(1.1);
    xd.push(1.1); xd.push(1.0);
    xd.push(1.0); xd.push(0.8);
    xd.push(10.0); xd.push(10.2);
    xd.push(10.2); xd.push(9.9);
    xd.push(9.8); xd.push(10.1);
    xd.push(10.1); xd.push(10.0);
    xd.push(10.0); xd.push(9.8);
    xd.push(1.0); xd.push(10.2);
    xd.push(1.2); xd.push(9.9);
    xd.push(0.8); xd.push(10.1);
    xd.push(1.1); xd.push(10.0);
    xd.push(1.0); xd.push(9.8);
    let x: TensorF64 = tensor_f64_from_vec(15, 2, xd);

    // --- Predict via direct argmin over squared distances ---
    print("PROBE-2 case: 03_clustering");
    print("n_samples: 15");
    print("labels:");

    let mut count_0: i64 = 0;
    let mut count_1: i64 = 0;
    let mut count_2: i64 = 0;

    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut best_label: i64 = 0;
        let mut best_sq: f64 = kmeans_f64_squared_distance_row_center(&x, r, &centers, 0);
        let sq1: f64 = kmeans_f64_squared_distance_row_center(&x, r, &centers, 1);
        if sq1 < best_sq {
            best_sq = sq1;
            best_label = 1;
        };
        let sq2: f64 = kmeans_f64_squared_distance_row_center(&x, r, &centers, 2);
        if sq2 < best_sq {
            best_sq = sq2;
            best_label = 2;
        };
        print_int(best_label);
        if best_label == 0 { count_0 = count_0 + 1; };
        if best_label == 1 { count_1 = count_1 + 1; };
        if best_label == 2 { count_2 = count_2 + 1; };
        r = r + 1;
    };

    // Sort the 3 counts ascending for partition-invariant comparison.
    let mut a: i64 = count_0;
    let mut b: i64 = count_1;
    let mut c: i64 = count_2;
    if a > b { let t: i64 = a; a = b; b = t; };
    if b > c { let t: i64 = b; b = c; c = t; };
    if a > b { let t: i64 = a; a = b; b = t; };

    print("cluster_size_signature_sorted:");
    print_int(a);
    print_int(b);
    print_int(c);

    return 0;
}
