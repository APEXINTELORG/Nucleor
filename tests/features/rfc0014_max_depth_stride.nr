// RFC-0014 extension positive: monotonic counter strides may be
// constant positive increments larger than one.

#[max_depth = 6]
fn stride_walk(depth: i64) -> i64 {
    if depth >= 6 {
        return depth;
    };
    return stride_walk(depth + 2);
}

fn main() -> i64 {
    let got: i64 = stride_walk(0);
    if got != 6 { return 1; };
    print("OK rfc0014_max_depth_stride");
    return 0;
}
