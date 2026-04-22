// vec_arith — RFC-0024 phase 1 (cont): Vec<i64> arithmetic + format helpers.

fn is_pos(x: i64) -> i64 { if x > 0 { return 1; }; return 0; }
fn is_huge(x: i64) -> i64 { if x > 1000 { return 1; }; return 0; }

fn main() -> i64 {
    let mut fail: i64 = 0;
    let mut v: Vec<i32> = Vec::new();
    v.push(2); v.push(4); v.push(6); v.push(8);

    let mut w: Vec<i32> = Vec::new();
    w.push(1); w.push(2); w.push(3); w.push(4);

    if vec_avg_i64(v) != 5 { fail = fail + 1; print("FAIL avg"); };
    if vec_dot_i64(v, w) != 60 { fail = fail + 1; print("FAIL dot"); };  // 2+8+18+32 = 60
    if vec_count_eq_i64(v, 4) != 1 { fail = fail + 1; print("FAIL count_eq 4"); };
    if vec_count_eq_i64(v, 99) != 0 { fail = fail + 1; print("FAIL count_eq 0"); };
    if vec_any_i64(v, is_pos) != 1 { fail = fail + 1; print("FAIL any pos"); };
    if vec_any_i64(v, is_huge) != 0 { fail = fail + 1; print("FAIL any huge"); };
    if vec_all_i64(v, is_pos) != 1 { fail = fail + 1; print("FAIL all pos"); };
    if vec_all_i64(v, is_huge) != 0 { fail = fail + 1; print("FAIL all huge"); };

    if str_eq(format_bool("flag = {}", 1), "flag = true") == 0 {
        fail = fail + 1; print("FAIL format_bool true");
    };
    if str_eq(format_bool("flag = {}", 0), "flag = false") == 0 {
        fail = fail + 1; print("FAIL format_bool false");
    };
    if str_eq(format3_iii("{}/{}/{}", 1, 2, 3), "1/2/3") == 0 {
        fail = fail + 1; print("FAIL format3_iii");
    };

    if fail == 0 { print("OK vec_arith"); return 0; };
    return 1;
}
