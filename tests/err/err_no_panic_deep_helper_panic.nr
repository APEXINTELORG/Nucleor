// EXPECT: RT-002 call to `guard_top()` reaches same-file panic-prone code
// RT-G3 v0842: #[no_panic] catches a deeper same-file helper chain.

fn must_be_nonzero(x: i64) -> i64 {
    if x == 0 {
        panic("zero");
    };
    return x;
}

fn guard_mid(x: i64) -> i64 {
    return must_be_nonzero(x);
}

fn guard_top(x: i64) -> i64 {
    return guard_mid(x);
}

#[no_panic]
fn controller_step(x: i64) -> i64 {
    return guard_top(x);
}

fn main() -> i64 {
    return controller_step(0);
}
