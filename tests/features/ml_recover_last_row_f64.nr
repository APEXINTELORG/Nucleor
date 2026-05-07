import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_last_row_f64 — extract the final hidden row from a
// (seq_len, hidden_dim) tensor.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // 3 rows × 4 cols. Last row = [9, 10, 11, 12].
    let mut hd: Vec<f64> = Vec::new();
    hd.push(1.0); hd.push(2.0); hd.push(3.0); hd.push(4.0);
    hd.push(5.0); hd.push(6.0); hd.push(7.0); hd.push(8.0);
    hd.push(9.0); hd.push(10.0); hd.push(11.0); hd.push(12.0);
    let h: TensorF64 = tensor_f64_from_vec(3, 4, hd);

    let last: TensorF64 = ai_last_row_f64(&h);
    if last.shape.rows != 1 { print("FAIL last rows"); fail = fail + 1; };
    if last.shape.cols != 4 { print("FAIL last cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&last, 0, 0), 9.0, eps) != 1 { print("FAIL last 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&last, 0, 3), 12.0, eps) != 1 { print("FAIL last 3"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_last_row_f64"); return 0; };
    print("FAIL ml_recover_last_row_f64");
    return 1;
}
