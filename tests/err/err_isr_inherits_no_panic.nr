// EXPECT: RT-002

#[isr]
fn bad_isr_panic() {
    panic("boom");
}

fn main() -> i32 {
    return 0;
}
