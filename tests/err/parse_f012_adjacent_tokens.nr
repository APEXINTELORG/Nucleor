// EXPECT: PARSE-LET-SEMI expected `;` after let statement
// Audit close: F-012 (Critical, silent miscompile).
// Pre-fix `1 2 3 4 5` parsed as initializer `1`, then discarded
// `2`, `3`, `4`, and expression-stmt `5;`.
fn main() -> i32 {
    let x: i64 = 1 2 3 4 5;
    return x as i32;
}
