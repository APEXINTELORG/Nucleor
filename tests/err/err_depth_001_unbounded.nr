// EXPECT: error[DEPTH-001] analysis cannot bound recursive path

#[max_depth = 5]
fn depth_unbounded(depth: i64) -> i64 {
    return depth_unbounded(depth + 1);
}

fn main() -> i64 {
    return depth_unbounded(0);
}
