// repro_v80_int_lit_as_handle.nr — v0.4.80 silent SIGSEGV close.
// Pre-fix `vec_len(42)` and similar literal-int-as-Vec/tokenizer-
// handle patterns printed a WARNING and continued — the compiler
// shipped a binary that SIGSEGVed at runtime when the helper
// dereferenced the int as `NVec*`. Two WARNING sites promoted
// to ERROR + panic. Tokenizer-handle parallel close in same
// commit.
//
// EXPECT: build fails (msg contains "int literal as Vec handle").

fn main() -> i64 {
    let n: i64 = vec_len(42);
    println!("{}", n);
    return 0;
}
