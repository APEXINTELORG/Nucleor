// RFC-0014 extension positive: simple guard helpers are inlined by
// the conservative source-level analyzer.

fn depth_done(d: i64, limit: i64) -> bool {
    return d >= limit;
}

#[max_depth = 5]
fn helper_guard_walk(depth: i64) -> i64 {
    if depth_done(depth, 4) {
        return depth;
    };
    return helper_guard_walk(depth + 1);
}

fn main() -> i64 {
    let got: i64 = helper_guard_walk(0);
    if got != 4 { return 1; };
    print("OK rfc0014_max_depth_helper_guard");
    return 0;
}
