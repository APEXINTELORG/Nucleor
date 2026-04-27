// Probe: str_to_int on overflowing input should PANIC
fn main() -> i64 {
    let huge: str = "99999999999999999999999";
    let v: i64 = str_to_int(huge);
    println!("{}", v);
    return 0;
}
