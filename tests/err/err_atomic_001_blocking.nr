// EXPECT: ATOMIC-001 blocking call inside #[atomic] function
#[atomic]
fn bad_atomic_blocking() -> i64 {
    sleep_ms(1);
    return 0;
}

fn main() -> i64 {
    return bad_atomic_blocking();
}
