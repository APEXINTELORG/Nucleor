// v0.7.41 negative fixture — Rust 1.58+ inline format-arg `{name}`
// halts cleanly with explicit-arg workaround pointer.
fn main() -> i64 {
    let n: i64 = 42;
    let s: str = format!("{n}");
    print(s);
    return 0;
}
