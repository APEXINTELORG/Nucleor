import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_categorical_sample_f64 — deterministic categorical
// sampling using explicit thresholds. Probabilities [0.5, 0.3, 0.2]
// have cumulative [0.5, 0.8, 1.0]. Threshold 0.4 → bucket 0,
// threshold 0.7 → bucket 1, threshold 0.95 → bucket 2.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let mut pd: Vec<f64> = Vec::new();
    pd.push(0.5); pd.push(0.3); pd.push(0.2);
    let p: TensorF64 = tensor_f64_from_vec(1, 3, pd);

    // 3 query thresholds, one per row.
    let mut td: Vec<f64> = Vec::new();
    td.push(0.4);
    td.push(0.7);
    td.push(0.95);
    let thresholds: TensorF64 = tensor_f64_from_vec(3, 1, td);

    // The rod expects probabilities expanded across all rows; replicate p.
    let mut pe: Vec<f64> = Vec::new();
    pe.push(0.5); pe.push(0.3); pe.push(0.2);
    pe.push(0.5); pe.push(0.3); pe.push(0.2);
    pe.push(0.5); pe.push(0.3); pe.push(0.2);
    let pep: TensorF64 = tensor_f64_from_vec(3, 3, pe);

    let s: TensorI64 = ai_categorical_sample_i64(&pep, &thresholds);
    if s.shape.rows != 3 { print("FAIL sample rows"); fail = fail + 1; };
    if tensor_i64_at(&s, 0, 0) != 0 { print("FAIL sample 0"); fail = fail + 1; };
    if tensor_i64_at(&s, 1, 0) != 1 { print("FAIL sample 1"); fail = fail + 1; };
    if tensor_i64_at(&s, 2, 0) != 2 { print("FAIL sample 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_categorical_sample_f64"); return 0; };
    print("FAIL ml_recover_categorical_sample_f64");
    return 1;
}
