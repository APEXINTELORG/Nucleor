// EXPECT: error[LEX-NUM-FLOAT-FORM]
// Leading-dot floats must be written with the explicit zero.
fn main() -> i64 {
    let x: f64 = .5;
    return 0;
}
