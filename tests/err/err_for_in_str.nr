// EXPECT: error[TYP-011] `for <var> in <str>` is not supported
// v0.4.152: `for c in s` for `s: str` silently produced 0
// iterations and the loop body never ran. Same hazard class as
// v0.4.135 (`"abc".len() == 0`): the kind-49 (for-collection)
// codegen calls `vec_len` / `vec_get` on the iterable; for a
// str pointer those return 0 / garbage because str layout
// doesn't match Vec layout. Adopters writing canonical Rust
// `for c in s.chars()` who dropped the `.chars()` got a passing
// build with no output. Detect at type-check: iterable type
// `str` / `String` / scalar / bool → halt with TYP-011 and a
// hint at `str_chars(s)` (returns Vec<i64> of byte values) or
// the explicit `while i < str_len(s)` walk. s1-only.

fn main() -> i32 {
    let s: str = "hello";
    for c in s {
        print_int(c);
    }
    0
}
