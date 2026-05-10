// EXPECT: OWN-G4-USE-AFTER-DROP conditional manual free
// G4-A-2: a free inside a loop may run before the post-loop read.
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    let mut i: i64 = 0;
    while i < 1 {
        vec_free(v);
        i = i + 1;
    };
    let n: i32 = vec_get(v, 0) as i32;
    n
}
