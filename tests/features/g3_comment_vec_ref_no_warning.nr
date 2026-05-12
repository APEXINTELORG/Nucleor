// G3-FP-1: this comment mentions Vec<&T>, but the source contains
// only owned integer indices. The regression gate heuristic must strip
// comments before counting Vec-of-reference patterns.
fn main() -> i32 {
    let mut indexes: Vec<i64> = Vec::new();
    vec_push(indexes, 0);
    vec_push(indexes, 1);
    vec_len(indexes) as i32
}
