fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(3);
    v.push(4);
    v.push(5);
    let r: i64 = match v {
        [first, .., last] => first + last,
        _ => 0,
    };
    if r != 8 { return 91; };
    return 0;
}
