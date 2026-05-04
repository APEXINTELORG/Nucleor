// v0.7.37 negative fixture — default-value parameter halts cleanly
// (was wrong-class NR020 expected `,`, got `=`).
fn add(self_v: i64, n: i64 = 1) -> i64 { return self_v + n; }
fn main() -> i64 {
    return 0;
}
