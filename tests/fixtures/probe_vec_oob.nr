// Probe: vec OOB should now PANIC by default
fn main() -> i64 {
    let v: Vec<i64> = vec![10, 20, 30];
    let bad: i64 = v[10];
    println!("{}", bad);
    return 0;
}
