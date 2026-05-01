// RFC-0014 extension positive: a visible mutually-recursive SCC with
// compatible bounds and monotonic edge updates composes safely.

#[max_depth = 6]
fn scc_a(depth: i64) -> i64 {
    if depth >= 6 { return depth; };
    return scc_b(depth + 1);
}

#[max_depth = 6]
fn scc_b(depth: i64) -> i64 {
    if depth >= 6 { return depth; };
    return scc_c(depth + 1);
}

#[max_depth = 6]
fn scc_c(depth: i64) -> i64 {
    if depth >= 6 { return depth; };
    return scc_a(depth + 1);
}

fn main() -> i64 {
    let got: i64 = scc_a(0);
    if got != 6 { return 1; };
    print("OK rfc0014_max_depth_scc");
    return 0;
}
