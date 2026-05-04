// v0.7.51 negative fixture — bare int-literal payload in variant
// pattern halts cleanly (was compiler SEGFAULT rc=139, no diag).
fn main() -> i64 {
    let opt: Option<i64> = Some(5);
    match opt { Some(1) => print("a"), _ => print("b") };
    return 0;
}
