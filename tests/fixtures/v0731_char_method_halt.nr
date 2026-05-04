// v0.7.31 negative fixture — `c.is_alphabetic()` Rust char-method
// idiom halts cleanly (was wrong-class TYP-005 about Vec<T>).
fn main() -> i64 {
    let c: char = 'A';
    let b: bool = c.is_alphabetic();
    return 0;
}
