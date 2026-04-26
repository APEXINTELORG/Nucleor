// t428_str_len_int_arg_diag.nr — v0.3.154 regression fixture (negative).
//
// Pre-v0.3.154, runtime helpers had no sig entries in the type
// checker, so type_expr's call-handling fell through to
// builtin_rtype(callee) WITHOUT validating any argument types.
// Adopters writing `str_len(42)` (passing an int where a str is
// expected) compiled cleanly and SIGSEGV'd at runtime when the C
// helper dereferenced 42 as a const char *. Same hazard class as
// v0.3.137-v0.3.153 silent miscompiles -- a real call you wrote
// produces a crash with no diagnostic.
//
// Fix (conservative): validate arg 0 type for the most common
// str-taking helpers (str_len, str_to_int, str_to_f64,
// str_to_int_with_base). Other helpers fall through to the
// existing no-arg-check path; they'll be added incrementally as
// audited. Each new helper added pins another adopter pain point
// behind a clean TYP-006 instead of a SIGSEGV.
//
// This fixture exists to confirm the diagnostic FIRES (this is a
// negative test). The verify mirror (when added) should:
//   - try to build this file
//   - assert the build prints "TYP-006" and "must be str (runtime helper)"
//   - assert the build does NOT produce a clean exe

fn main() -> i64 {
    let n: i64 = 42;
    let l: i64 = str_len(n);  // pre-fix: silent SIGSEGV; post-fix: TYP-006
    return l;
}
