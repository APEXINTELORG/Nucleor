// EXPECT: INIT-G11-READ-BEFORE-INIT
// Regression gate G-11 CFG join: a binding assigned on only some
// match arms is not definitely assigned after the match.
enum Choice { KeepUnset, SetIt }

fn main() -> i64 {
    let mut x: i64;
    let choice: Choice = Choice::SetIt;
    match choice {
        Choice::KeepUnset => { let _noop: i64 = 0; },
        Choice::SetIt => { x = 5; },
    };
    return x;
}
