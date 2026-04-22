// hashmap_str_i64.nr — RFC-0017 partial: HashMap<str, i64>

fn main() -> i32 {
    let mut fail: i64 = 0;

    let m: i64 = hashmap_new();
    if hashmap_len(m) != 0 { fail = fail + 1; print("FAIL: empty len\n"); };

    hashmap_insert(m, "alice", 30);
    hashmap_insert(m, "bob", 42);
    hashmap_insert(m, "carol", 17);
    if hashmap_len(m) != 3 { fail = fail + 1; print("FAIL: len 3\n"); };

    if hashmap_get(m, "alice") != 30 { fail = fail + 1; print("FAIL: get alice\n"); };
    if hashmap_get(m, "bob") != 42 { fail = fail + 1; print("FAIL: get bob\n"); };
    if hashmap_get(m, "carol") != 17 { fail = fail + 1; print("FAIL: get carol\n"); };
    if hashmap_get(m, "nobody") != 0 { fail = fail + 1; print("FAIL: get missing\n"); };

    if hashmap_contains(m, "alice") != 1 { fail = fail + 1; print("FAIL: contains alice\n"); };
    if hashmap_contains(m, "nobody") != 0 { fail = fail + 1; print("FAIL: contains missing\n"); };

    // Update
    hashmap_insert(m, "alice", 31);
    if hashmap_get(m, "alice") != 31 { fail = fail + 1; print("FAIL: updated alice\n"); };
    if hashmap_len(m) != 3 { fail = fail + 1; print("FAIL: len after update\n"); };

    // Remove
    hashmap_remove(m, "bob");
    if hashmap_len(m) != 2 { fail = fail + 1; print("FAIL: len after remove\n"); };
    if hashmap_contains(m, "bob") != 0 { fail = fail + 1; print("FAIL: bob removed\n"); };
    if hashmap_get(m, "carol") != 17 { fail = fail + 1; print("FAIL: carol still there\n"); };

    // Stress: insert many to trigger growth
    let mut i: i64 = 0;
    while i < 100 {
        hashmap_insert(m, "stress_key", i);
        i = i + 1;
    };
    // All 100 inserts of same key should leave len at 3 (unchanged set: alice, carol, stress_key)
    if hashmap_len(m) != 3 { fail = fail + 1; print("FAIL: dedupe insert\n"); };

    hashmap_clear(m);
    if hashmap_len(m) != 0 { fail = fail + 1; print("FAIL: after clear\n"); };

    hashmap_free(m);

    if fail == 0 { print("OK hashmap_str_i64\n"); return 0; };
    return 1;
}
