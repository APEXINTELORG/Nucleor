// EXPECT: error[DEPTH-002] static recursion depth

#[max_depth = 3]
fn stride_too_small(depth: i64) -> i64 {
    if depth >= 4 {
        return depth;
    };
    return stride_too_small(depth + 2);
}

fn main() -> i64 {
    return stride_too_small(0);
}
