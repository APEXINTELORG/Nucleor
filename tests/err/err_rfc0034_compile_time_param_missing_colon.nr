// EXPECT: build fails with NR020.
// RFC-0034 [] parameters require `Name: Kind`.

fn bad[N usize](x: i64) -> i64 {
    return x;
}

fn main() -> i32 {
    return 0;
}
