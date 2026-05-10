// EXPECT: ALIAS-G3-VEC-OF-REFS vec_insert_at
// G3-FN-1: the actual runtime helper is vec_insert_at, so the
// Vec<&T> guard must reach it instead of only a stale vec_insert name.
fn main() -> i32 {
    let x: i64 = 1;
    let mut v: Vec<&i64> = Vec::new();
    vec_insert_at(v, 0, &x);
    0
}
