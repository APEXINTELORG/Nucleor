// Probe: panic_add on overflow should PANIC
fn main() -> i64 {
    let big: i64 = 9223372036854775000;
    let r: i64 = panic_add(big, big);
    println!("{}", r);
    return 0;
}
