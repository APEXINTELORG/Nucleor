// v0.7.32 negative fixture — `s.chars()` Rust string-method idiom
// halts cleanly (was wrong-class TYP-005 about Vec<T>).
fn main() -> i64 {
    let s: str = "hi";
    for c in s.chars() { print("c"); };
    return 0;
}
