// EXPECT: ISR-001

#[isr]
fn bad_isr_param(x: i64) {
}

fn main() -> i32 {
    return 0;
}
