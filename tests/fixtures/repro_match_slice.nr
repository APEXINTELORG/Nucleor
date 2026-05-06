fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(3);
    v.push(4);
    v.push(5);
    let r: i64 = match v {
        [first, middle, last] => first + middle + last,
        _ => 0,
    };
    if r != 12 { return 91; };
    return 0;
}
