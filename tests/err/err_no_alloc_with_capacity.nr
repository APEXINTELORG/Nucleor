// EXPECT: RT-001
//
// Lane 6 / F-CONC-004 (audit 2026-05-08): the `#[no_alloc]` scanner
// now catches the canonical Vec::with_capacity allocation form.
// Pre-fix the substring scanner only knew `Vec::new` and missed
// `Vec::with_capacity`.
#[no_alloc]
fn bad_with_capacity() -> i64 {
    let mut v: Vec<i64> = Vec::with_capacity(16);
    v.push(1);
    return 0;
}

fn main() -> i64 {
    return bad_with_capacity();
}
