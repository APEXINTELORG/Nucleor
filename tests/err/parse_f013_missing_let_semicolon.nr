// EXPECT: PARSE-LET-SEMI expected `;` after let statement
// Audit close: F-013 (High, missing semicolon after let silently accepted).
fn main() -> i32 {
    let x: i64 = 1
    let y: i64 = 2;
    return (x + y) as i32;
}
