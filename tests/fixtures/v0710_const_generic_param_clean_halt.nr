// v0.7.10 (defensive halt): canonical Rust const-generic params
// `<const N: usize>` (used in `struct Buf<const N: usize> { ... }`,
// `fn id<const X: i32>() -> i32 { X }`) pre-fix surfaced as
// wrong-class `NR020: expected ',', got identifier` because
// parse_generic_params treats `const` as a bare param name. Now
// halts cleanly with a regular-fn-arg / hard-coded-value
// workaround pointer. Negative fixture (compile rejects).
struct Buf<const N: usize> {    // ← halts: const-generic unsupported
    data: i64,
}

fn main() -> i32 {
    print_int(0);
    return 0;
}
