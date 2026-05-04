// v0.7.4 (defensive halt): canonical Rust `extern "C" fn name() {
// body }` (FFI-exposed fn with body) pre-fix landed at `{` after
// parse_extern_fn returned, and parse_program surfaced it as
// wrong-class `statement-level keyword at module scope`. Now
// halts cleanly with a "drop extern \"C\"" workaround pointer.
// Negative fixture (compile rejects).
extern "C" fn callback(x: i64) -> i64 {    // ← halts: extern body unsupported
    return x * 3;
}

fn main() -> i32 {
    return 0;
}
