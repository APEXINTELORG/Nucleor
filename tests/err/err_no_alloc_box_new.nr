// EXPECT: RT-001
//
// Lane 6 / F-CONC-004 (audit 2026-05-08): the `#[no_alloc]` scanner
// now catches the `Box::new` heap-allocation form. Pre-fix Box::new
// was not in the no_alloc check list.
#[no_alloc]
fn bad_box_new() -> i64 {
    let _b: Box<i64> = Box::new(7);
    return 0;
}

fn main() -> i64 {
    return bad_box_new();
}
