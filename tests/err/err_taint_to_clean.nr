// EXPECT: TYP-008 type mismatch for binding
// Binding clean type to a tainted expression.
// Error test: tainted<i32> cannot be assigned to clean i32
fn get_input() -> tainted<i32> {
    99
}

fn main() -> i32 {
    let dirty: tainted<i32> = get_input();
    // This must fail — tainted cannot silently become clean
    let clean: i32 = dirty;
    clean
}
