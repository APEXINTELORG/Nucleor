// EXPECT: ISR-001

#[isr]
fn bad_isr_returns() -> i64 {
    return 1;
}

fn main() -> i32 {
    return 0;
}
