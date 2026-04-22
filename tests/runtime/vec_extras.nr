// vec_extras — RFC-0017 / RFC-0024 stdlib enrichment.
//
//   vec_first(v)            -> i64
//   vec_last(v)             -> i64
//   vec_is_empty(v)         -> i64
//   vec_swap(v, i, j)
//   vec_extend(dst, src)
//   vec_remove_at(v, i)
//   vec_insert_at(v, i, x)

fn main() -> i64 {
    let mut fail: i64 = 0;

    let v: Vec<i64> = vec_new();
    if vec_is_empty(v) != 1 { fail = fail + 1; print("FAIL is_empty fresh"); };

    vec_push(v, 10);
    vec_push(v, 20);
    vec_push(v, 30);

    if vec_is_empty(v) != 0  { fail = fail + 1; print("FAIL is_empty after push"); };
    if vec_first(v) != 10    { fail = fail + 1; print("FAIL vec_first"); };
    if vec_last(v) != 30     { fail = fail + 1; print("FAIL vec_last"); };

    // vec_swap(0, 2) -> [30, 20, 10]
    vec_swap(v, 0, 2);
    if vec_first(v) != 30    { fail = fail + 1; print("FAIL swap first"); };
    if vec_last(v) != 10     { fail = fail + 1; print("FAIL swap last"); };

    // vec_insert_at(1, 99) -> [30, 99, 20, 10]
    vec_insert_at(v, 1, 99);
    if vec_len(v) != 4       { fail = fail + 1; print("FAIL insert len"); };
    if vec_get(v, 1) != 99   { fail = fail + 1; print("FAIL insert val"); };

    // vec_remove_at(0) -> [99, 20, 10]
    vec_remove_at(v, 0);
    if vec_len(v) != 3       { fail = fail + 1; print("FAIL remove len"); };
    if vec_first(v) != 99    { fail = fail + 1; print("FAIL remove first"); };

    // vec_extend
    let other: Vec<i64> = vec_new();
    vec_push(other, 7);
    vec_push(other, 8);
    vec_extend(v, other);
    if vec_len(v) != 5       { fail = fail + 1; print("FAIL extend len"); };
    if vec_last(v) != 8      { fail = fail + 1; print("FAIL extend last"); };

    // vec_first / vec_last on empty Vec return 0
    let empty: Vec<i64> = vec_new();
    if vec_first(empty) != 0 { fail = fail + 1; print("FAIL first empty"); };
    if vec_last(empty) != 0  { fail = fail + 1; print("FAIL last empty"); };

    if fail == 0 { print("OK vec_extras"); return 0; };
    return 1;
}
