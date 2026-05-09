// EXPECT: RT-008 recursion exceeds max_depth
// Lane 3 (F-DIAG-006): RT-008 had no negative test.

#[max_depth(2)]
fn deep(x: i64) -> i64 {
    if x <= 0 { return 0; };
    return 1 + deep(x - 1);
}

fn main() -> i64 {
    return deep(100);
}
