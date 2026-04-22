// hashset_basic.nr — RFC-0017 phase 4: HashSet<str>

fn main() -> i32 {
    let mut fail: i64 = 0;

    let s: i64 = hashset_new();
    if hashset_len(s) != 0 { fail = fail + 1; print("FAIL: empty len\n"); };

    hashset_insert(s, "apple");
    hashset_insert(s, "banana");
    hashset_insert(s, "cherry");
    if hashset_len(s) != 3 { fail = fail + 1; print("FAIL: after inserts\n"); };

    if hashset_contains(s, "apple") != 1 { fail = fail + 1; print("FAIL: contains apple\n"); };
    if hashset_contains(s, "banana") != 1 { fail = fail + 1; print("FAIL: contains banana\n"); };
    if hashset_contains(s, "grape") != 0 { fail = fail + 1; print("FAIL: contains missing\n"); };

    // Dedupe
    hashset_insert(s, "apple");
    if hashset_len(s) != 3 { fail = fail + 1; print("FAIL: dedupe\n"); };

    hashset_remove(s, "banana");
    if hashset_len(s) != 2 { fail = fail + 1; print("FAIL: after remove\n"); };
    if hashset_contains(s, "banana") != 0 { fail = fail + 1; print("FAIL: banana removed\n"); };

    hashset_clear(s);
    if hashset_len(s) != 0 { fail = fail + 1; print("FAIL: after clear\n"); };

    hashset_free(s);

    if fail == 0 { print("OK hashset_basic\n"); return 0; };
    return 1;
}
