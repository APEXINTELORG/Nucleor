// EXPECT: raw-ref syntax `&raw const`
// Q7 lock-in — v0.8.22. Rust 1.82 `&raw const x` syntax halts
// cleanly with workaround (use `&x` or i64 cast at FFI boundary).

fn main() -> i64 {
    let x: i64 = 5;
    let r = &raw const x;
    return 0;
}
