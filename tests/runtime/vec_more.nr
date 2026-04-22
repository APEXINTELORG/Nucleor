// vec_more — RFC-0024 phase 1 (cont): Vec scalar utilities + f64 reductions.
//
// Covers:
//   vec_contains_i64 / vec_index_of_i64 — linear search
//   vec_reverse_i64 — in-place reverse
//   vec_sort_i64 — qsort ascending
//   vec_clone_i64 / vec_clear_i64 — lifecycle helpers

fn main() -> i64 {
    let mut fail: i64 = 0;
    let mut v: Vec<i32> = Vec::new();
    v.push(3); v.push(1); v.push(4); v.push(1);
    v.push(5); v.push(9); v.push(2); v.push(6);

    if vec_contains_i64(v, 5) != 1 { fail = fail + 1; print("FAIL contains 5"); };
    if vec_contains_i64(v, 99) != 0 { fail = fail + 1; print("FAIL not-contains 99"); };
    if vec_index_of_i64(v, 4) != 2 { fail = fail + 1; print("FAIL index_of 4"); };
    if vec_index_of_i64(v, 99) != (0 - 1) { fail = fail + 1; print("FAIL index_of missing"); };

    let cloned: Vec<i32> = vec_clone_i64(v);
    vec_reverse_i64(cloned);
    if vec_get(cloned, 0) != 6 { fail = fail + 1; print("FAIL reversed[0]"); };
    if vec_get(cloned, 7) != 3 { fail = fail + 1; print("FAIL reversed[7]"); };

    let sorted: Vec<i32> = vec_clone_i64(v);
    vec_sort_i64(sorted);
    if vec_get(sorted, 0) != 1 { fail = fail + 1; print("FAIL sorted[0]"); };
    if vec_get(sorted, 7) != 9 { fail = fail + 1; print("FAIL sorted[7]"); };

    let mut to_clear: Vec<i32> = vec_clone_i64(v);
    vec_clear_i64(to_clear);
    if vec_len(to_clear) != 0 { fail = fail + 1; print("FAIL cleared len"); };

    if fail == 0 { print("OK vec_more"); return 0; };
    return 1;
}
