// T3.10 (v0.3.9) RT-008 fixture — used by the verify gate to
// assert the recursion check warns when a #[deadline] fn calls
// itself without a #[max_depth] opt-out annotation.

#[deadline = 100000]
#[no_alloc]
fn fib_unbounded(n: i64) -> i64 {
    if n <= 1 {
        return n;
    };
    return fib_unbounded(n - 1) + fib_unbounded(n - 2);
}

fn main() -> i64 {
    return fib_unbounded(5);
}
