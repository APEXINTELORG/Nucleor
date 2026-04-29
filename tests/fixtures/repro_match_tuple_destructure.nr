fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(8);
    v.push(2);
    let r: i64 = match v {
        (a, b) => a - b,
        _ => 0,
    };
    if r != 6 { return 91; };
    return 0;
}
