// EXPECT: ALIAS-G3-VEC-OF-REFS vec_extend
// G3-FN-1: vec_extend into Vec<&T> must be guarded like vec_push.
fn main() -> i32 {
    let x: i64 = 1;
    let y: i64 = 2;
    let mut dst: Vec<&i64> = Vec::new();
    let mut src: Vec<&i64> = Vec::new();
    vec_push(src, &x);
    vec_push(src, &y);
    vec_extend(dst, src);
    0
}
