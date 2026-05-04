// v0.7.26 negative fixture — `extern "C" { ... }` block form halts
// cleanly (was wrong-class NR020 expected `{`, got `;`).
extern "C" {
    fn cfn(x: i64) -> i64;
}
fn main() -> i64 {
    return 0;
}
