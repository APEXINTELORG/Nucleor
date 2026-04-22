// btreeset_basic.nr — RFC-0017 phase 3: ordered set

fn main() -> i32 {
    let mut fail: i64 = 0;

    let s: i64 = btreeset_new();

    btreeset_insert(s, "zebra");
    btreeset_insert(s, "apple");
    btreeset_insert(s, "monkey");
    if btreeset_len(s) != 3 { fail = fail + 1; print("FAIL: len 3\n"); };

    if btreeset_contains(s, "apple") != 1 { fail = fail + 1; print("FAIL: contains apple\n"); };
    if btreeset_contains(s, "missing") != 0 { fail = fail + 1; print("FAIL: contains missing\n"); };

    // Dedupe
    btreeset_insert(s, "apple");
    if btreeset_len(s) != 3 { fail = fail + 1; print("FAIL: dedupe\n"); };

    btreeset_remove(s, "monkey");
    if btreeset_len(s) != 2 { fail = fail + 1; print("FAIL: after remove\n"); };

    btreeset_clear(s);
    if btreeset_len(s) != 0 { fail = fail + 1; print("FAIL: cleared\n"); };

    btreeset_free(s);

    if fail == 0 { print("OK btreeset_basic\n"); return 0; };
    return 1;
}
