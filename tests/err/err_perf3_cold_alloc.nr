// EXPECT: PERF-3 cold-path heap allocation hint
// Lane 3 (F-DIAG-006): PERF-3 had no negative test.

fn warm_helper(x: i64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(x);
    v.push(x + 1);
    return v.get(0) + v.get(1);
}

fn main() -> i64 {
    return warm_helper(1);
}
