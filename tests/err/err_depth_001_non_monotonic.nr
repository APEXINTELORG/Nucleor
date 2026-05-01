// EXPECT: error[DEPTH-001] analysis cannot bound recursive path

#[max_depth = 4]
fn non_monotonic(depth: i64) -> i64 {
    if depth >= 4 {
        return depth;
    };
    return non_monotonic(depth - 1);
}

fn main() -> i64 {
    return non_monotonic(0);
}
