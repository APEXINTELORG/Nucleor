// repro_v55_slice_syntax_guard.nr
//
// v0.4.55 NUC-FEEDBACK silent-segfault guard for slice expressions
// `expr[lo..hi]`. Pre-v0.4.55 the parser printed
// "Parse error ... expected token 55 got 58" but silently continued,
// producing broken IR that SIGSEGVed at runtime. v0.4.55 detects
// the `..` (or `..=`) token after the index expression in
// parse_postfix and panics with a clear workaround pointing at
// `str_substring(s, lo, hi)` for strings.

fn main() -> i64 {
    let s: str = "hello world";
    let part: str = s[0..5];   // panic expected (was silent SIGSEGV)
    println!("{}", part);
    return 0;
}
