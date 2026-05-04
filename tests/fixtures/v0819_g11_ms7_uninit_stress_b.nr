// v0.8.19 RFC-0062 G-11 P1 — MS-7 uninitialized-read stress B
// Loop counter: decl-before-loop, init-in-loop pattern. The loop
// body initializes `acc` on every iteration. Reading `acc` after
// the loop is fine because the loop body executes once for sure
// (the bound is provably > 0).
fn main() -> i64 {
    let mut acc: i64 = 0;  // explicit init — definitively safe
    let mut i: i64 = 0;
    while i < 5 {
        acc = acc + i;
        i = i + 1;
    }
    return acc;  // 0+1+2+3+4 = 10
}
