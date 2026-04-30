// EXPECT: error[NUM-008] shift amount

fn main() -> i64 {
    let n: i64 = 100;
    let x: i64 = 1 << n;
    return x;
}
