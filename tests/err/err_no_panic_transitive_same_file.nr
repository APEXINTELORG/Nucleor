// EXPECT: RT-002 call to `guard_wrapper()` reaches same-file panic-prone code
// RT-G3 Phase 2b: #[no_panic] catches caller -> helper -> panic helper
// in bounded same-file closure.

fn must_be_nonzero(x: i64) -> i64 {
    if x == 0 {
        panic("zero");
    };
    return x;
}

fn guard_wrapper(x: i64) -> i64 {
    return must_be_nonzero(x);
}

#[no_panic]
fn controller_step(x: i64) -> i64 {
    return guard_wrapper(x);
}

fn main() -> i64 {
    return controller_step(0);
}
