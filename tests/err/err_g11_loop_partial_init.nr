// EXPECT: INIT-G11-READ-BEFORE-INIT
// Audit-pass-1 G-11 CFG join: assignment inside a while body does
// not dominate a post-loop read because the loop may execute zero
// times.
fn main() -> i64 {
    let mut x: i64;
    let mut cond: i64 = 0;
    while cond == 1 {
        x = 7;
        cond = 0;
    };
    return x;
}
