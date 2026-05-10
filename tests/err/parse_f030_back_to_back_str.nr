// EXPECT: PARSE-LET-SEMI expected `;` after let statement
// Audit close: F-030 (High, adjacent string literal silently dropped).
// Nucleor does not define C-style adjacent string concatenation.
fn main() -> i32 {
    let s: str = "a""b";
    return str_len(s) as i32;
}
