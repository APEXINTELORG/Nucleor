// EXPECT: error[DEPTH-005] estimated stack use

#[max_depth = 200]
fn depth_stack_heavy(depth: i64) -> i64 {
    if depth >= 1 {
        return depth;
    };
    let a0: i64 = depth + 0;
    let a1: i64 = a0 + 1;
    let a2: i64 = a1 + 1;
    let a3: i64 = a2 + 1;
    let a4: i64 = a3 + 1;
    let a5: i64 = a4 + 1;
    let a6: i64 = a5 + 1;
    let a7: i64 = a6 + 1;
    let a8: i64 = a7 + 1;
    let a9: i64 = a8 + 1;
    return depth_stack_heavy(depth + 1);
}

fn main() -> i64 {
    return depth_stack_heavy(0);
}
