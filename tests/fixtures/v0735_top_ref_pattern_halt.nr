// v0.7.35 negative fixture — top-level `ref` binding in match arm
// halts cleanly (was wrong-class NR020 expected `=>`, got identifier).
fn main() -> i64 {
    let x: i64 = 5;
    let r: i64 = match x { ref n => *n };
    return 0;
}
