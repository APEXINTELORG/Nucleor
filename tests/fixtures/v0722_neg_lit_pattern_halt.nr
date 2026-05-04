// v0.7.22 negative fixture — bare negative-literal pattern halts
// cleanly (was wrong-class NR020 expected `=>`, got integer literal).
fn main() -> i64 {
    let x: i64 = -5;
    match x {
        -5 => { print("neg5"); }
        _ => { print("other"); }
    };
    return 0;
}
