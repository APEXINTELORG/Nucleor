// Probe: -(i64::MIN) should PANIC under strict-arith default
fn main() -> i64 {
    let m: i64 = 0 - 9223372036854775807 - 1;  // i64::MIN via subtract
    let r: i64 = -m;
    println!("{}", r);
    return 0;
}
