fn main() -> i64 {
    let n: i64 = 7;
    let r: i64 = match n {
        m @ 1..=10 => m + 1,
        _ => 0,
    };
    if r != 8 { return 91; };
    return 0;
}
