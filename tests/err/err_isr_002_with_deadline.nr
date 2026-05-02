// EXPECT: ISR-002

#[isr]
#[deadline = 10]
fn bad_isr_deadline() {
}

fn main() -> i32 {
    return 0;
}
