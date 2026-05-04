// v0.7.33 negative fixture — `v.dedup()` Rust Vec mutating-method
// idiom halts cleanly (was wrong-class TYP-005 about Vec<T>).
fn main() -> i64 {
    let mut v: Vec<i64> = vec![1, 1, 2, 3];
    v.dedup();
    return 0;
}
