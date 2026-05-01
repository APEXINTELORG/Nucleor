// RFC-0014 runtime fixture: static shape is bounded for normal non-negative
// entry, but this call starts below zero and trips the debug depth counter.
// EXPECT: runtime abort with DEPTH-003.

#[max_depth = 5]
fn depth_runtime(depth: i64) -> i64 {
    if depth >= 4 {
        return depth;
    };
    return depth_runtime(depth + 1);
}

fn main() -> i64 {
    return depth_runtime(-10);
}
