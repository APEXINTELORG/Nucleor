// env_str_helpers — RFC-0017 / RFC-0022 stdlib enrichment.
//
//   env_has(name)        -> i64
//   env_keys()           -> Vec<str>   (only checks non-empty)
//   str_is_empty(s)      -> i64
//   str_count(s, n)      -> i64
//   str_reverse(s)       -> str
//   str_trim_start(s)    -> str
//   str_trim_end(s)      -> str

fn main() -> i64 {
    let mut fail: i64 = 0;

    // env_has + env_set + env_unset round-trip
    env_unset("NUC_GATE_ENV_FOO");
    if env_has("NUC_GATE_ENV_FOO") != 0 { fail = fail + 1; print("FAIL env_has unset"); };
    env_set("NUC_GATE_ENV_FOO", "bar");
    if env_has("NUC_GATE_ENV_FOO") != 1 { fail = fail + 1; print("FAIL env_has set"); };
    env_unset("NUC_GATE_ENV_FOO");

    // env_keys() should be non-empty (process always has at least PATH/HOME/etc.)
    let keys: Vec<str> = env_keys();
    if vec_len(keys) == 0 { fail = fail + 1; print("FAIL env_keys empty"); };

    // str_is_empty
    if str_is_empty("") != 1     { fail = fail + 1; print("FAIL str_is_empty true"); };
    if str_is_empty("x") != 0    { fail = fail + 1; print("FAIL str_is_empty false"); };

    // str_count: 'l' appears 3 times in "hello world"
    if str_count("hello world", "l") != 3 { fail = fail + 1; print("FAIL str_count l"); };
    if str_count("aaaa", "aa") != 2       { fail = fail + 1; print("FAIL str_count aa"); };
    if str_count("abc", "z") != 0         { fail = fail + 1; print("FAIL str_count miss"); };

    // str_reverse
    if !str_eq(str_reverse("abcd"), "dcba") { fail = fail + 1; print("FAIL str_reverse"); };
    if !str_eq(str_reverse(""), "")          { fail = fail + 1; print("FAIL str_reverse empty"); };

    // str_trim_start / str_trim_end
    if !str_eq(str_trim_start("  hi  "), "hi  ") { fail = fail + 1; print("FAIL trim_start"); };
    if !str_eq(str_trim_end("  hi  "), "  hi")   { fail = fail + 1; print("FAIL trim_end"); };
    if !str_eq(str_trim_start("\t\nhi"), "hi")   { fail = fail + 1; print("FAIL trim_start ws"); };

    if fail == 0 { print("OK env_str_helpers"); return 0; };
    return 1;
}
