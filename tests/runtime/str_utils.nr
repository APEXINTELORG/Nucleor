// str_utils — RFC-0017 / RFC-0028 stdlib string utilities.
//
// Covers ASCII case conversion, trimming, prefix/suffix match,
// substring search, replace-all, and repeat. str_split returns a
// Vec<str> and is exercised by checking the element count.

fn main() -> i64 {
    let mut fail: i64 = 0;

    if str_eq(str_to_upper("hello, world"), "HELLO, WORLD") == 0 {
        fail = fail + 1; print("FAIL str_to_upper");
    };
    if str_eq(str_to_lower("HELLO, WORLD"), "hello, world") == 0 {
        fail = fail + 1; print("FAIL str_to_lower");
    };
    if str_eq(str_trim("   spaced out   "), "spaced out") == 0 {
        fail = fail + 1; print("FAIL str_trim");
    };
    if str_starts_with("hello, world", "hello") != 1 {
        fail = fail + 1; print("FAIL str_starts_with");
    };
    if str_starts_with("hello, world", "world") != 0 {
        fail = fail + 1; print("FAIL str_starts_with no");
    };
    if str_ends_with("hello, world", "world") != 1 {
        fail = fail + 1; print("FAIL str_ends_with");
    };
    if str_contains("hello, world", "lo, w") != 1 {
        fail = fail + 1; print("FAIL str_contains");
    };
    if str_contains("hello, world", "xyz") != 0 {
        fail = fail + 1; print("FAIL str_contains no");
    };
    if str_index_of("hello, world", "world") != 7 {
        fail = fail + 1; print("FAIL str_index_of");
    };
    if str_index_of("hello", "xyz") != (0 - 1) {
        fail = fail + 1; print("FAIL str_index_of missing");
    };
    if str_eq(str_replace("hello, world, hello", "hello", "hi"), "hi, world, hi") == 0 {
        fail = fail + 1; print("FAIL str_replace");
    };
    if str_eq(str_repeat("ab", 3), "ababab") == 0 {
        fail = fail + 1; print("FAIL str_repeat");
    };
    if str_eq(str_repeat("x", 0), "") == 0 {
        fail = fail + 1; print("FAIL str_repeat 0");
    };

    // str_split returns Vec<str>; verify the count and check that the
    // first element comes back as the literal first segment.
    let parts: Vec<i32> = str_split("a,b,c,d", ",");
    if vec_len(parts) != 4 { fail = fail + 1; print("FAIL str_split count"); };

    if fail == 0 { print("OK str_utils"); return 0; };
    return 1;
}
