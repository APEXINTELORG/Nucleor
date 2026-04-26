// Probe: str_char_at with negative index should PANIC
fn main() -> i64 {
    let s: str = "hello";
    let bad: i64 = str_char_at(s, 0 - 5);
    println!("{}", bad);
    return 0;
}
