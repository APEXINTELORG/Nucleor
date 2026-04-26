// Probe: shift amount >= 64 should PANIC under strict-arith default
fn main() -> i64 {
    let x: i64 = 1;
    let amt: i64 = 64;
    let r: i64 = x << amt;
    println!("{}", r);
    return 0;
}
