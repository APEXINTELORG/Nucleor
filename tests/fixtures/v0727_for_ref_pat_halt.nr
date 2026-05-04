// v0.7.27 negative fixture — ref-pattern in for-loop binding position
// halts cleanly (was wrong-class NR020 expected token 57, got identifier).
fn main() -> i64 {
    let v: Vec<i64> = vec![1, 2, 3];
    for &x in &v { print("x"); };
    return 0;
}
