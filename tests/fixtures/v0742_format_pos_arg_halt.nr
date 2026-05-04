// v0.7.42 negative fixture — Rust positional format-arg `{0}` halts
// cleanly with linear-args workaround pointer.
fn main() -> i64 {
    let s: str = format!("{0} {1} {0}", 1, 2);
    print(s);
    return 0;
}
