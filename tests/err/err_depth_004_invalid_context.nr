// EXPECT: error[DEPTH-004] `#[max_depth = N]` must use a positive integer literal

#[max_depth = "four"]
fn depth_bad_attr(depth: i64) -> i64 {
    return depth;
}

fn main() -> i64 {
    return depth_bad_attr(0);
}
