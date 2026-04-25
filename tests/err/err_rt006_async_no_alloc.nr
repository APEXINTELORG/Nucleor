// EXPECT: RT-006 RT attribute
// T3.8 (v0.3.7) negative — `#[no_alloc]` on an `async fn` is
// rejected. Async is non-deterministic by design (thread
// scheduling, IO wakeups) and cannot honor any RT contract.

#[no_alloc]
async fn poll_loop(x: i64) -> i64 {
    return x + 1;
}

fn main() -> i64 {
    return 0;
}
