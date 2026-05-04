// EXPECT: C string literals `c"..."` are not yet supported
// Q8 lock-in — v0.8.22. Rust 1.77 c-string literal halts
// cleanly with workaround (use normal string literal with
// explicit NUL handling at FFI boundary).

fn main() -> i64 {
    let s = c"hello";
    return 0;
}
