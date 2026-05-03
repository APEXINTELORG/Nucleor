// v0.7.3 (defensive halt): canonical Rust raw-pointer types
// `*const T` / `*mut T` (`let p: *const i64 = ...;`,
// `fn read(p: *const i64)`) pre-fix surfaced as wrong-class
// `NR020: parse_primary cannot start expression at token kind 73`
// (the `const` keyword following `*`) because parse_type had no
// `*` branch. Now halts cleanly with a borrow-ref / i64-FFI
// workaround pointer. Negative fixture (compile rejects).
fn main() -> i32 {
    let x: i64 = 42;
    let p: *const i64 = &x;    // ← halts: raw pointer type unsupported
    print_int(0);
    return 0;
}
