fn main() -> i64 {
    let x: i64 = 42;
    let r: &i64 = &x;
    print(*r);
    let f: f64 = 3.7;
    print((f as i64) + 1);
    return 0;
}
