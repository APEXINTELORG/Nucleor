// EXPECT: error[DEPTH-003] recursive SCC

#[max_depth = 4]
fn scc_bad_a(depth: i64) -> i64 {
    if depth >= 4 { return depth; };
    return scc_bad_b(depth + 1);
}

#[max_depth = 4]
fn scc_bad_b(depth: i64) -> i64 {
    if depth >= 4 { return depth; };
    return scc_bad_c(depth + 1);
}

#[max_depth = 4]
fn scc_bad_c(depth: i64) -> i64 {
    if depth >= 4 { return depth; };
    return scc_bad_a(depth);
}

fn main() -> i64 {
    return scc_bad_a(0);
}
