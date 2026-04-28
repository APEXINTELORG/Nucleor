// repro_v67_str_ord_pointer_guard.nr
//
// v0.4.67 NUC-FEEDBACK silent-miscompute close for str ordering
// ops `<`, `<=`, `>`, `>=`. Pre-fix `a < b` for two str values
// did integer pointer compare — wholly disconnected from
// lexicographic byte order. Adopters writing canonical Rust got
// quiet wrong results.
//
// v0.4.67 extends the v0.4.52 close (which only caught == and !=)
// to also catch ops 32/33/34/35 with str/str operands. Workaround
// hint points at `str_cmp(a, b) <op> 0` for canonical lex ordering.

fn main() -> i64 {
    let a: str = "abc";
    let b: str = "xyz";
    if a < b {                          // TYP-011 expected
        println!("less");
    } else {
        println!("greater-or-eq");
    };
    return 0;
}
