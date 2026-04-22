// str_padding — RFC-0017 / RFC-0028 stdlib enrichment.
//
//   str_pad_left(s, width, fill_char)   -> str   (right-align)
//   str_pad_right(s, width, fill_char)  -> str   (left-align)
//   str_center(s, width, fill_char)     -> str
//   str_join(sep, vec)                  -> str
//   str_lines(s)                        -> Vec<str>
//   str_chars(s)                        -> Vec<i64>

fn main() -> i64 {
    let mut fail: i64 = 0;

    // str_pad_left: right-align "42" in width 5 with space (32)
    if !str_eq(str_pad_left("42", 5, 32), "   42") {
        fail = fail + 1; print("FAIL pad_left ws");
    };
    // Numeric "42" in width 5 with '0' (48) -> "00042"
    if !str_eq(str_pad_left("42", 5, 48), "00042") {
        fail = fail + 1; print("FAIL pad_left zero");
    };

    // str_pad_right: left-align
    if !str_eq(str_pad_right("hi", 5, 46), "hi...") {
        fail = fail + 1; print("FAIL pad_right .");
    };

    // str_center
    if !str_eq(str_center("hi", 6, 45), "--hi--") {
        fail = fail + 1; print("FAIL center even");
    };
    // Odd extra goes to right side
    if !str_eq(str_center("hi", 5, 45), "-hi--") {
        fail = fail + 1; print("FAIL center odd");
    };

    // Width <= len: return original (no truncation)
    if !str_eq(str_pad_left("hello", 3, 32), "hello") {
        fail = fail + 1; print("FAIL pad_left no-trunc");
    };

    // str_join
    let parts: Vec<str> = vec_new();
    vec_push(parts, "a");
    vec_push(parts, "b");
    vec_push(parts, "c");
    if !str_eq(str_join(",", parts), "a,b,c") {
        fail = fail + 1; print("FAIL str_join basic");
    };
    if !str_eq(str_join("", parts), "abc") {
        fail = fail + 1; print("FAIL str_join empty sep");
    };

    // str_join with empty vec
    let empty: Vec<str> = vec_new();
    if !str_eq(str_join(",", empty), "") {
        fail = fail + 1; print("FAIL str_join empty vec");
    };

    // str_lines: simple
    let lines: Vec<str> = str_lines("foo\nbar\nbaz");
    if vec_len(lines) != 3 {
        fail = fail + 1; print("FAIL lines count");
    };
    // CRLF: \r should be stripped
    let crlf_lines: Vec<str> = str_lines("a\r\nb\r\nc");
    if vec_len(crlf_lines) != 3 {
        fail = fail + 1; print("FAIL lines crlf count");
    };

    // str_chars: "abc" -> [97, 98, 99]
    let chars: Vec<i64> = str_chars("abc");
    if vec_len(chars) != 3 {
        fail = fail + 1; print("FAIL chars count");
    };
    if vec_get(chars, 0) != 97 {
        fail = fail + 1; print("FAIL chars 0");
    };
    if vec_get(chars, 2) != 99 {
        fail = fail + 1; print("FAIL chars 2");
    };

    if fail == 0 { print("OK str_padding"); return 0; };
    return 1;
}
