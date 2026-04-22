// vec_helpers — RFC-0024 phase 1: Vec<i64> functional helpers.
//
// `vec_map_i64` / `vec_filter_i64` / `vec_fold_i64` take a function
// pointer (the unresolved-identifier path in lower_expr emits
// `ir_fn_ptr` for any name not in the local symbol table). Pairs with
// `vec_sum_i64` / `vec_min_i64` / `vec_max_i64` for closure-free
// reductions.

fn dbl(x: i64) -> i64 { return x * 2; }
fn keep_even(x: i64) -> i64 { return 1 - (x - (x / 2) * 2); }
fn add(a: i64, b: i64) -> i64 { return a + b; }

fn main() -> i64 {
    let mut fail: i64 = 0;
    let mut v: Vec<i32> = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);
    v.push(4);
    v.push(5);

    if vec_sum_i64(v) != 15 { fail = fail + 1; print("FAIL sum"); };
    if vec_min_i64(v) != 1 { fail = fail + 1; print("FAIL min"); };
    if vec_max_i64(v) != 5 { fail = fail + 1; print("FAIL max"); };

    if vec_fold_i64(v, 100, add) != 115 { fail = fail + 1; print("FAIL fold"); };

    let doubled: Vec<i32> = vec_map_i64(v, dbl);
    if vec_sum_i64(doubled) != 30 { fail = fail + 1; print("FAIL map sum"); };

    let evens: Vec<i32> = vec_filter_i64(v, keep_even);
    if vec_sum_i64(evens) != 6 { fail = fail + 1; print("FAIL filter sum"); };

    if fail == 0 { print("OK vec_helpers"); return 0; };
    return 1;
}
