// EXPECT: error[DEPTH-003] mutually recursive cycle

#[max_depth = 4]
fn depth_cycle_a(depth: i64) -> i64 {
    if depth >= 4 {
        return depth;
    };
    return depth_cycle_b(depth + 1);
}

#[max_depth = 3]
fn depth_cycle_b(depth: i64) -> i64 {
    if depth >= 4 {
        return depth;
    };
    return depth_cycle_a(depth + 1);
}

fn main() -> i64 {
    return depth_cycle_a(0);
}
