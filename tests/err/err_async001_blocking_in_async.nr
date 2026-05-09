// EXPECT: ASYNC-001 blocking call inside async function
// Lane 3 (F-DIAG-006): ASYNC-001 had no negative test.
// async fns must not call blocking primitives.

#[async]
fn slow_io() -> i64 {
    sleep_ms(100);
    return 0;
}

fn main() -> i64 {
    return slow_io();
}
