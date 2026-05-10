// EXPECT: error[LEX-STRING-NEWLINE]
// Raw newlines inside string literals must be written as \n escapes.
fn main() -> i64 {
    let s: str = "first
second";
    return 0;
}
