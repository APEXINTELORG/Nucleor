// v0.6.48 (probe finding 2026-05-02-str-runtime-helpers-reject-amp-but-strict-
// accepts): str runtime helpers now accept both `s` and `&s`. Pre-fix `&s`
// was rejected with TYP-006 even though `&s` lowers identically to `s`.
fn main() -> i32 {
    let s: str = "hello";
    let n: i64 = str_len(&s);
    print_int(n as i32);
    let c: str = str_concat(&s, " world");
    print(&c);
    let sub: str = str_substring(&s, 1, 4);
    print(&sub);
    return 0;
}
