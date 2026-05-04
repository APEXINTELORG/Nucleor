// v0.7.34 negative fixture — `.copied()` Rust iterator-conversion idiom
// halts cleanly (was wrong-class TYP-005 about Vec<T>).
fn main() -> i64 {
    let v: Vec<i64> = vec![1, 2, 3];
    let r: Vec<i64> = v.iter().copied().collect();
    return 0;
}
