// v0.7.53 negative fixture — float-literal payload in variant
// pattern halts cleanly (was compiler SEGFAULT rc=139, no diag).
fn main() -> i64 {
    let opt: Option<f64> = Some(1.5);
    match opt { Some(1.5) => print("a"), _ => print("b") };
    return 0;
}
