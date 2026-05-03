// EXPECT: build fails with NR020.
// RFC-0034 [] defaults for unsigned compile-time parameters must not accept negative literals.

fn bad[N: usize = -1](x: i64) -> i64 {
    return x;
}

fn main() -> i32 {
    return 0;
}
