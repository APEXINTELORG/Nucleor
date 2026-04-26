// Probe: str_substring with end > strlen should PANIC by default
fn main() -> i64 {
    let s: str = "hi";
    let bad: str = str_substring(s, 0, 100);
    println!("{}", bad);
    return 0;
}
