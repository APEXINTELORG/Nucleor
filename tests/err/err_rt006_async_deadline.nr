// EXPECT: RT-006 RT attribute
// T3.8 (v0.3.7) negative — `#[deadline = N]` on an `async fn`
// is rejected. Same root cause as the no_alloc case: async
// scheduling makes deadline budgets meaningless.

#[deadline = 1000]
async fn motor_step(x: i64) -> i64 {
    return x + 1;
}

fn main() -> i64 {
    return 0;
}
