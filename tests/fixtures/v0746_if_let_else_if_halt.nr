// v0.7.46 negative fixture — `else if` (or `else if let`) chained
// after an `if let` halts cleanly (was wrong-class NR020 token 13).
fn main() -> i64 {
    let a: Option<i64> = Some(5);
    let b: Option<i64> = None;
    if let Some(x) = a { print("a"); } else if let Some(y) = b { print("b"); };
    return 0;
}
