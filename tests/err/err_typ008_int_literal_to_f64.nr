// EXPECT: error[TYP-008]
// Regression gate Layer 2 F-005: integer literal must not silently initialize f64.
fn main() -> i32 {
    let f: f64 = 3;
    print_f64(f);
    0
}
