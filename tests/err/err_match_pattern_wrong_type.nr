fn main() -> i64 {
    let n: i64 = 5;
    return match n {
        (x, y) => x + y,
        _ => 0,
    };
}
