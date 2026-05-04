// v0.7.29 negative fixture — Rust Unicode-escape char literal halts
// cleanly (was wrong-class loop-label v0.7.2 halt).
fn main() -> i64 {
    let c: i64 = '\u{0041}' as i64;
    return 0;
}
