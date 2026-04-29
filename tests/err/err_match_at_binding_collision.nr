fn main() -> i64 {
    let x: i64 = 3;
    return match x {
        x @ 1..=5 => x,
        _ => 0,
    };
}
