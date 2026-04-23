// RFC-0028 phase 3 (v0.2.155) — three new format3_* combinations:
//   format3_sii(tmpl, str, i64, i64)
//   format3_iss(tmpl, i64, str, str)
//   format3_sss(tmpl, str, str, str)
//
// Mirrors v0.2.153 (format2_*) for the 3-arg surface. Each builds
// the output by chaining the corresponding single-arg helper three
// times. Verifies wiring through get_rt_name + is_ptr_ret +
// is_ptr_arg + emit_externs in s1 AND tools_suite (drift gate
// enforces parity).

fn main() -> i64 {
    let mut fail: i64 = 0;

    let s1: str = format3_sii("{}={}+{}", "sum", 2, 3);
    if str_eq(s1, "sum=2+3") == 0 { fail = fail + 1; print("FAIL format3_sii"); print(s1); };

    let s2: str = format3_iss("{}: {} -> {}", 7, "src", "dst");
    if str_eq(s2, "7: src -> dst") == 0 { fail = fail + 1; print("FAIL format3_iss"); print(s2); };

    let s3: str = format3_sss("{}/{}/{}", "a", "b", "c");
    if str_eq(s3, "a/b/c") == 0 { fail = fail + 1; print("FAIL format3_sss"); print(s3); };

    if fail == 0 { print("OK format3_combos"); };
    return fail;
}
