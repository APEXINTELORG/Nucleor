// v0.7.24 negative fixture — bare negative literal payload inside
// variant pattern halts cleanly (was wrong-class NR020).
fn main() -> i64 {
    let opt: Option<i64> = Some(-5);
    match opt {
        Some(-5) => { print("n5"); }
        _ => { print("o"); }
    };
    return 0;
}
