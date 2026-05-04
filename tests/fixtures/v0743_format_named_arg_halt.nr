// v0.7.43 negative fixture — Rust named format-arg `format!("{x}", x = 5)`
// halts cleanly with explicit-positional workaround pointer.
fn main() -> i64 {
    let s: str = format!("{x}", x = 5);
    print(s);
    return 0;
}
