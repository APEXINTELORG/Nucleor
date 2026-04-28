// repro_v51_str_plus_str_guard.nr
//
// v0.4.51 NUC-FEEDBACK silent-segfault guard for `str + str`.
// Pre-fix `let s: str = "a" + "b"` SILENTLY SIGSEGVed at runtime
// because the binop lower emitted i64_add on the two str pointers,
// producing a garbage pointer that crashed when passed to print_str.
//
// Rust itself doesn't allow `&str + &str`, so adopters coming from
// Rust would expect a compile error — but Nucleor's permissive
// binop lower silently accepted the pointer-add.
//
// v0.4.51 emits TYP-011 with a hint pointing at str_concat(a, b).
// (TYP-011 is in the error-tier code list so it halts the build.)

fn main() -> i64 {
    let s: str = "hello" + " " + "world";   // TYP-011 expected (twice)
    println!("{}", s);
    return 0;
}
