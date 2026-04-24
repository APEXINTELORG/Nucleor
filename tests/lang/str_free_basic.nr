// RFC-0030 phase 4 (v0.2.169) — str_free builtin frees heap-
// allocated strings returned by str_concat / str_substring /
// sb_to_str / format_* / int_to_str / etc.
//
// Safety: str_free MUST NOT be called on string literals — they
// live in the rodata section and free() corrupts the heap. Only
// call on values you got from one of the allocating builtins.

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Allocate via str_concat, then free.
    let s: str = str_concat("foo", "bar");
    if str_eq(s, "foobar") == 0 { fail = fail + 1; print("FAIL concat"); };
    str_free(s);

    // Allocate via str_substring, then free.
    let t: str = str_substring("abcdefg", 2, 5);
    if str_eq(t, "cde") == 0 { fail = fail + 1; print("FAIL substring"); };
    str_free(t);

    // Allocate via int_to_str, then free.
    let n: str = int_to_str(42);
    if str_eq(n, "42") == 0 { fail = fail + 1; print("FAIL int_to_str"); };
    str_free(n);

    if fail == 0 { print("OK str_free_basic"); };
    return fail;
}
