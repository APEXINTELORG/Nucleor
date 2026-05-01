// EXPECT: ATOMIC-003 Cell/RefCell forbidden inside #[atomic]
#[atomic]
fn bad_atomic_cell() -> i64 {
    let c: Cell<i64> = Cell::new(1);
    return 0;
}

fn main() -> i64 {
    return bad_atomic_cell();
}
