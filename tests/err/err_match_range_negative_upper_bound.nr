// EXPECT: build fails with MATCH-014.
// Negative literal upper bounds in range patterns are intentionally
// unsupported until unary-minus pattern grammar lands.

fn main() -> i64 {
    let value: i64 = 0;
    return match value {
        0..=-1 => 1,
        _ => 0,
    };
}
