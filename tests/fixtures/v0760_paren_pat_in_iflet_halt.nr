// v0.7.60 negative fixture — paren-wrapped pattern in `if let` / `while
// let` halts cleanly (was wrong-class NR020 token kind 11).
fn main() -> i64 {
    let mut o: Option<i64> = Some(5);
    while let (Some(x)) = o { o = None; };
    return 0;
}
