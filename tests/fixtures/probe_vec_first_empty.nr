// Probe: vec_first on empty should PANIC by default
fn main() -> i64 {
    let empty: Vec<i64> = vec_new();
    let x: i64 = vec_first(empty);
    println!("{}", x);
    return 0;
}
