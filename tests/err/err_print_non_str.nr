// EXPECT: error[TYP-006] argument 0 of 'print' must be str
// v0.4.149: print() / println() / eprint() / eprintln() take a
// `str` (const char*) but the kind-7 type-check's
// `needs_str_arg0` list (added in v0.3.155 to catch
// `str_len(42)`-style runtime helper misuse) didn't include
// these output-side helpers. Pre-fix `print(p)` for `p: P`
// (some struct) silently passed the struct's i64 cell to
// `__nucleor_print_str`, which read the heap content as a
// c-string and printed garbage bytes (or SIGSEGV'd if the
// pointer was invalid). Adding `print/println/eprint/eprintln`
// to the existing list catches the bug at the same TYP-006
// site, keeping the diagnostic shape consistent with str_len /
// str_eq / panic / print_raw.

struct P { x: i64 }

fn main() -> i32 {
    let p: P = P { x: 1 };
    print(p);
    0
}
