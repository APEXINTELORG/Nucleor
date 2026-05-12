// EXPECT: OWN-G4-USE-AFTER-DROP
// Regression gate G-4 CFG join: a manual free on only one branch is
// still unsafe for a later read, because the post-join value may
// point at freed storage depending on the branch taken.
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    let cond: i64 = 1;
    if cond == 1 {
        vec_free(v);
    };
    let n: i64 = vec_get(v, 0);
    return n as i32;
}
