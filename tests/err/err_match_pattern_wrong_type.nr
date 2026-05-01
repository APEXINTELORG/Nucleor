// EXPECT: error[TYP-010] tuple/slice pattern requires Vec<T> scrutinee
fn main() -> i64 {
    let n: i64 = 5;
    return match n {
        (x, y) => x + y,
        _ => 0,
    };
}
