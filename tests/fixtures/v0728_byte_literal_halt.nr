// v0.7.28 negative fixture — Rust byte literal `b'A'` halts cleanly
// (was wrong-class TYP-005 undefined function 'b()').
fn main() -> i64 {
    let b: u8 = b'A';
    return 0;
}
