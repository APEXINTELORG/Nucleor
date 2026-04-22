// vec.nr — Vec basics
fn main() -> i64 {
    let mut fail: i64 = 0;
    let v: Vec<i32> = Vec::new();
    if vec_len(v) != 0 { print("FAIL vec: empty len"); fail = fail + 1; };
    vec_push(v, 10);
    vec_push(v, 20);
    vec_push(v, 30);
    if vec_len(v) != 3 { print("FAIL vec: len after pushes"); fail = fail + 1; };
    if vec_get(v, 0) != 10 { print("FAIL vec: get 0"); fail = fail + 1; };
    if vec_get(v, 1) != 20 { print("FAIL vec: get 1"); fail = fail + 1; };
    if vec_get(v, 2) != 30 { print("FAIL vec: get 2"); fail = fail + 1; };
    if fail == 0 { print("OK vec"); return 0; };
    return 1;
}
