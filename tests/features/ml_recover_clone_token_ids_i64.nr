import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_clone_token_ids_i64 — single-pass tensor copy.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let mut td: Vec<i64> = Vec::new();
    td.push(7); td.push(11); td.push(13);
    let original: TensorI64 = tensor_i64_from_vec(1, 3, td);

    let cloned: TensorI64 = ai_clone_token_ids_i64(&original);
    if cloned.shape.rows != 1 { print("FAIL clone rows"); fail = fail + 1; };
    if cloned.shape.cols != 3 { print("FAIL clone cols"); fail = fail + 1; };
    if tensor_i64_at(&cloned, 0, 0) != 7 { print("FAIL clone 0"); fail = fail + 1; };
    if tensor_i64_at(&cloned, 0, 1) != 11 { print("FAIL clone 1"); fail = fail + 1; };
    if tensor_i64_at(&cloned, 0, 2) != 13 { print("FAIL clone 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_clone_token_ids_i64"); return 0; };
    print("FAIL ml_recover_clone_token_ids_i64");
    return 1;
}
