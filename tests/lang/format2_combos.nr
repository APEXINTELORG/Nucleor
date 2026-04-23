// RFC-0028 phase 2 (v0.2.153) — three new format2_* combinations:
//   format2_ss(tmpl, str, str)
//   format2_is(tmpl, i64, str)
//   format2_ff(tmpl, f64, f64)
//
// Each builds the output by chaining the corresponding single-arg
// format helper twice. Verifies the new builtins are wired through
// get_rt_name + is_ptr_ret + is_ptr_arg + emit_externs.

fn main() -> i64 {
    let mut fail: i64 = 0;

    let s1: str = format2_ss("from={}, to={}", "earth", "mars");
    if str_eq(s1, "from=earth, to=mars") == 0 { fail = fail + 1; print("FAIL format2_ss"); print(s1); };

    let s2: str = format2_is("count={}, name={}", 42, "answer");
    if str_eq(s2, "count=42, name=answer") == 0 { fail = fail + 1; print("FAIL format2_is"); print(s2); };

    // f64 args: format_f64 uses %g (default precision); confirm the
    // template substitution lands in the right places.
    let pi: f64 = 3.14;
    let e: f64 = 2.72;
    let s3: str = format2_ff("pi={}, e={}", pi, e);
    if str_eq(s3, "pi=3.14, e=2.72") == 0 { fail = fail + 1; print("FAIL format2_ff"); print(s3); };

    if fail == 0 { print("OK format2_combos"); };
    return fail;
}
