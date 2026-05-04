// v0.7.30 negative fixture — `5.abs()` Rust integer-method idiom
// halts cleanly (was wrong-class TYP-005 about Vec<T>).
fn main() -> i64 {
    let x: i64 = 5.abs();
    return 0;
}
