// v0.7.40 negative fixture — `v.into_iter()` Rust idiom halts cleanly
// (was wrong-class TYP-005 about Vec<T>).
fn main() -> i64 {
    let v: Vec<i64> = vec![1, 2];
    for x in v.into_iter() { print("x"); };
    return 0;
}
