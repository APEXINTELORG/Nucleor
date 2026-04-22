// string_type.nr — RFC-0017 partial: heap-allocated String

fn main() -> i32 {
    let mut fail: i64 = 0;

    let s: i64 = string_from_str("hello");
    if string_len(s) != 5 { fail = fail + 1; print("FAIL: len 5\n"); };
    if string_get_byte(s, 0) != 104 { fail = fail + 1; print("FAIL: byte 0 != 'h'\n"); };

    string_push_str(s, ", world");
    if string_len(s) != 12 { fail = fail + 1; print("FAIL: len 12 after push\n"); };

    if string_eq_str(s, "hello, world") != 1 { fail = fail + 1; print("FAIL: eq_str\n"); };
    if string_starts_with(s, "hello") != 1 { fail = fail + 1; print("FAIL: starts_with\n"); };
    if string_ends_with(s, "world") != 1 { fail = fail + 1; print("FAIL: ends_with\n"); };
    if string_contains(s, ", w") != 1 { fail = fail + 1; print("FAIL: contains\n"); };

    let cloned: i64 = string_clone(s);
    if string_eq(s, cloned) != 1 { fail = fail + 1; print("FAIL: cloned eq\n"); };
    if string_len(cloned) != 12 { fail = fail + 1; print("FAIL: cloned len\n"); };

    string_clear(s);
    if string_len(s) != 0 { fail = fail + 1; print("FAIL: after clear\n"); };

    string_push_byte(s, 65);  // 'A'
    string_push_byte(s, 66);  // 'B'
    if string_eq_str(s, "AB") != 1 { fail = fail + 1; print("FAIL: byte build\n"); };

    string_free(s);
    string_free(cloned);

    if fail == 0 { print("OK string_type\n"); return 0; };
    return 1;
}
