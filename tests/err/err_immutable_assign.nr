// EXPECT: OWN-008 cannot assign to immutable binding
// This file should FAIL ownership checking. `x` was declared without `mut`.
fn main() -> i64 {
    let x: i64 = 10;
    x = 20;
    return 0;
}
