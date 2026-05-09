// EXPECT: error[TYP-041]
// Lane 1 audit fix (2026-05-08) — closes F-016 (generic param name
// shadowing a primitive type). Pre-fix `fn f<i64>(x: i64)` was
// silently accepted; `i64` got rebound as a generic param,
// substituting at use-site instead of the primitive.
fn use_it<i64>(x: i64) -> i64 { x }
fn main() -> i32 {
    print_int(0);
    0
}
