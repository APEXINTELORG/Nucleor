// EXPECT: RT-001 allocates but `busy` is marked #[no_alloc]
// RFC-0001 phase 1 (v0.2.157) — `#[no_alloc]` negative case.
//
// `busy` is marked #[no_alloc] but uses Vec::new() and .push(),
// both of which allocate. The v1 source-level scan finds the
// substring `Vec::new(` (and `.push(`) in the body and fires
// RT-001 per violation.
#[no_alloc]
fn busy() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(1);
    return 0;
}

fn main() -> i64 {
    return busy();
}
