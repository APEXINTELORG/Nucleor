// v0.7.45 negative fixture — tuple-struct pattern in match arm halts
// cleanly (was wrong-class NR020 expected `=>`, got `(`).
struct P(i64, i64);
fn main() -> i64 {
    let p: P = P(1, 2);
    match p { P(a, b) => print("x") };
    return 0;
}
