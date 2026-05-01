// EXPECT: RT-002 panic-prone call inside a function declared with [no_panic]

fn bad_op(x: i64) -> i64 with [no_panic] {
    panic("boom");
    return x;
}

fn main() -> i64 {
    return bad_op(0);
}
