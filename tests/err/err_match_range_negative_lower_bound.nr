// EXPECT: build fails with MATCH-014.
// Negative literal lower bounds in range patterns are intentionally
// unsupported until unary-minus pattern grammar lands.

fn main() -> i64 {
    let value: i64 = 0 - 5;
    return match value {
        -10..=-1 => 1,
        _ => 0,
    };
}
