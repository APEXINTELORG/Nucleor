// Lane 2 positive (G4-cast): cast-walk fix must not regress
// legitimate `vec_get(v, idx) as i32` reads while the Vec is
// alive.
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 42);
    let n: i32 = vec_get(v, 0) as i32;
    vec_free(v);
    n
}
