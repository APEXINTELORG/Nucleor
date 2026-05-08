// Lane 6 / V1 (audit 2026-05-08): the default str_substring helper
// now validates `end <= strlen(s)` and uses int64 throughout. The
// positive path (substring within range) must continue to work.
fn main() -> i64 {
    let mut fail: i64 = 0;
    let s: str = "abcdef";
    if !str_eq(str_substring(s, 0, 3), "abc") { fail = fail + 1; print("FAIL [0..3]"); };
    if !str_eq(str_substring(s, 2, 5), "cde") { fail = fail + 1; print("FAIL [2..5]"); };
    if !str_eq(str_substring(s, 0, 6), "abcdef") { fail = fail + 1; print("FAIL full"); };
    if !str_eq(str_substring(s, 3, 3), "") { fail = fail + 1; print("FAIL empty"); };
    if fail == 0 { print("OK lane6_str_substring_legit"); };
    return fail;
}
