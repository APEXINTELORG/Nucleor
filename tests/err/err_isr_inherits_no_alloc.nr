// EXPECT: RT-001

#[isr]
fn bad_isr_alloc() {
    let mut v: Vec<i32> = Vec::new();
    v.push(1);
}

fn main() -> i32 {
    return 0;
}
