// T3.10 (v0.3.9) RT-008 opt-out fixture — same shape as
// t310_rt008_recursion.nr but with `#[max_depth = 8]` declaring
// a bounded recursion ceiling. Build must be CLEAN (no RT-008).

#[deadline = 100000]
#[no_alloc]
#[max_depth = 8]
fn fib_bounded(n: i64) -> i64 {
    if n <= 1 {
        return n;
    };
    return fib_bounded(n - 1) + fib_bounded(n - 2);
}

fn main() -> i64 {
    return fib_bounded(5);
}
