// v0.7.21 negative fixture — parenthesized range expression
// `(0..3).collect()` halts cleanly (was wrong-class NR020 expected
// `)`, got token 58).
fn main() -> i64 {
    for i in (0..3) { print("i"); };
    return 0;
}
