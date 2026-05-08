// RFC-0062 G-3 Phase 3 — positive lock-in. The recommended
// adopter mitigation for Vec-of-references is to store indices
// into an owned `Vec<i64>` instead of `Vec<&T>`. ALIAS-G3-VEC-OF-REFS
// fires only when vec_push / vec_insert lands on a binding whose
// declared type contains `Vec<&`; an owned `Vec<i64>` of indices
// is fine and must compile cleanly.

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 0);
    vec_push(v, 1);
    let n: i64 = vec_len(v);
    print_int(n as i32);
    0
}
