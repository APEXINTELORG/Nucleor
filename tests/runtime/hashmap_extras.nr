// hashmap_extras — RFC-0017 stdlib enrichment.
//
//   hashmap_is_empty(m)              -> i64
//   hashmap_get_or(m, key, default)  -> i64
//   hashmap_merge(dst, src)          -> i64  (number of entries copied)
//   hashmap_clone(m)                 -> hashmap handle

fn main() -> i64 {
    let mut fail: i64 = 0;

    let m: i64 = hashmap_new();
    if hashmap_is_empty(m) != 1 { fail = fail + 1; print("FAIL is_empty fresh"); };

    hashmap_insert(m, "alpha", 1);
    hashmap_insert(m, "beta", 2);
    hashmap_insert(m, "gamma", 3);

    if hashmap_is_empty(m) != 0 { fail = fail + 1; print("FAIL is_empty after insert"); };

    // hashmap_get_or: hit + miss
    if hashmap_get_or(m, "alpha", 999) != 1 {
        fail = fail + 1; print("FAIL get_or hit");
    };
    if hashmap_get_or(m, "missing", 999) != 999 {
        fail = fail + 1; print("FAIL get_or miss");
    };

    // hashmap_merge: copy src into dst (overwrites existing keys)
    let other: i64 = hashmap_new();
    hashmap_insert(other, "delta", 4);
    hashmap_insert(other, "alpha", 100);  // collides with m's "alpha"
    let copied: i64 = hashmap_merge(m, other);
    if copied != 2 { fail = fail + 1; print("FAIL merge count"); };
    if hashmap_get(m, "delta") != 4 { fail = fail + 1; print("FAIL merge new key"); };
    if hashmap_get(m, "alpha") != 100 { fail = fail + 1; print("FAIL merge overwrite"); };
    if hashmap_len(m) != 4 { fail = fail + 1; print("FAIL merge len"); };

    // hashmap_clone: deep copy, mutations to clone don't affect original
    let cl: i64 = hashmap_clone(m);
    if hashmap_len(cl) != 4 { fail = fail + 1; print("FAIL clone len"); };
    hashmap_insert(cl, "epsilon", 5);
    if hashmap_contains(m, "epsilon") != 0 {
        fail = fail + 1; print("FAIL clone isolation src");
    };
    if hashmap_contains(cl, "epsilon") != 1 {
        fail = fail + 1; print("FAIL clone isolation dst");
    };

    // hashmap_clone of empty
    let empty: i64 = hashmap_new();
    let empty_clone: i64 = hashmap_clone(empty);
    if hashmap_is_empty(empty_clone) != 1 {
        fail = fail + 1; print("FAIL clone empty");
    };

    if fail == 0 { print("OK hashmap_extras"); return 0; };
    return 1;
}
