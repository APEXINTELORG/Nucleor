// v0.7.54 negative fixture — paren-wrapped payload inside variant
// pattern halts cleanly (was wrong-class NR020 expected `)`, got int).
fn main() -> i64 {
    let opt: Option<i64> = Some(5);
    match opt { Some((1)) => print("a"), _ => print("b") };
    return 0;
}
