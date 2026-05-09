// EXPECT: error[TYP-042]
// Lane 1 audit fix (2026-05-08) — closes F-015 (duplicate type
// parameter `<T, T>`). Pre-fix this was silently accepted; the second
// `T` shadowed the first at substitution time. Rust E0403.
fn dup<T, T>(x: T, y: T) -> T { x }
fn main() -> i32 {
    print_int(0);
    0
}
