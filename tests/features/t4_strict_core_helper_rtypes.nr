// T-4 strict inference positive lock for core runtime helper return types.
// Under NUC_STRICT_INFERENCE=1 these assignments must not fall through to
// the empty-type sentinel.

fn main() -> i64 {
    let s: str = "  abcdef  ";
    let n: i64 = str_len(s);
    let c: i64 = str_char_at(s, 2);
    let c2: i64 = str_char_at_strict(s, 2);
    let sub: str = str_substring(s, 2, 5);
    let sub2: str = str_substring_strict(s, 2, 5);
    let trimmed: str = str_trim(s);
    let left: str = str_trim_start(s);
    let right: str = str_trim_end(s);
    let argv0: str = args_get(0);
    let source: str = file_read_string("tests/features/t4_strict_core_helper_rtypes.nr");
    if n != 10 { return 1; };
    if c != 97 { return 2; };
    if c2 != 97 { return 4; };
    if str_eq(sub, "abc") != 1 { return 8; };
    if str_eq(sub2, "abc") != 1 { return 16; };
    if str_eq(trimmed, "abcdef") != 1 { return 32; };
    if str_eq(left, "abcdef  ") != 1 { return 64; };
    if str_eq(right, "  abcdef") != 1 { return 128; };
    if str_len(argv0) <= 0 { return 256; };
    if str_len(source) <= 0 { return 512; };
    return 0;
}
