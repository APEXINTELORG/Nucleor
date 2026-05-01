// EXPECT: error[DEPTH-001] analysis cannot bound recursive path

fn not_a_guard(d: i64, limit: i64) -> bool {
    return d < limit;
}

#[max_depth = 4]
fn helper_unproven(depth: i64) -> i64 {
    if not_a_guard(depth, 4) {
        return depth;
    };
    return helper_unproven(depth + 1);
}

fn main() -> i64 {
    return helper_unproven(0);
}
