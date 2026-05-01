// T3.10 (v0.3.9) RT-008 opt-out fixture — same shape as
// t310_rt008_recursion.nr but with `#[max_depth = 8]` declaring
// a bounded recursion ceiling. Build must be CLEAN (no RT-008).

#[deadline = 100000]
#[no_alloc]
#[max_depth = 5]
fn fib_bounded(depth: i64) -> i64 {
    if depth >= 4 {
        return depth;
    };
    return fib_bounded(depth + 1);
}

fn main() -> i64 {
    return fib_bounded(0);
}
