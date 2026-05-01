// EXPECT: error[DEPTH-002] static recursion depth

#[max_depth = 2]
fn depth_too_small(depth: i64) -> i64 {
    if depth >= 4 {
        return depth;
    };
    return depth_too_small(depth + 1);
}

fn main() -> i64 {
    return depth_too_small(0);
}
