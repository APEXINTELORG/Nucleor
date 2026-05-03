// v0.7.9 (defensive halt): canonical Rust `async { ... }` block
// expression pre-fix surfaced as wrong-class `error[TYP-005]:
// undefined function async()` because expand_async_strip_keyword
// only handles `async fn` (not `async {`), and parse_primary then
// treats `async` as a fn call. Now halts cleanly with a "drop the
// `async` keyword" workaround pointer (Nucleor's runtime is
// single-threaded by default; for threaded use async_spawn).
// Negative fixture (compile rejects).
fn main() -> i32 {
    let f = async {       // ← halts: async block unsupported
        return 42;
    };
    print_int(0);
    return 0;
}
