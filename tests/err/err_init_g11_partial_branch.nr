// EXPECT: INIT-G11-READ-BEFORE-INIT read of 'x' before it is definitely assigned
// RFC-0062 G-11 Phase 2b/3/4 — only one arm of the if/else
// assigns the binding. The DA flow analysis intersects __init_*
// keys at the merge point: one arm has 1, the other has 0 →
// post-join 0. Subsequent read fires INIT-G11-READ-BEFORE-INIT.
// This is the "MS-7 hazard" the brief specifically calls out.
fn main() -> i64 {
    let mut x: i64;
    let cond: i64 = 1;
    if cond == 1 {
        x = 5;
    };
    return x;
}
