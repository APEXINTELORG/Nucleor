// EXPECT: ISR-003

#[isr(target = "host")]
fn bad_isr_host_target() {
}

fn main() -> i32 {
    return 0;
}
