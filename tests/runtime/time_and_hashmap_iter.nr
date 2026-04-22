// time_and_hashmap_iter — RFC-0017 stdlib enrichment.
//
// time_iso_now()           -> "YYYY-MM-DDTHH:MM:SSZ" (UTC, length 20)
// time_format_iso(secs)    -> same shape for any unix timestamp
// hashmap_keys(h)          -> Vec<str>
// hashmap_values(h)        -> Vec<i64>

import "stdlib/rods/hashmap.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    // ISO format: epoch is well-defined.
    let epoch_iso: str = time_format_iso(0);
    if str_eq(epoch_iso, "1970-01-01T00:00:00Z") == 0 {
        fail = fail + 1; print("FAIL epoch ISO");
    };

    // time_iso_now is whatever the current time is, but the shape must match.
    let now: str = time_iso_now();
    if str_len(now) != 20 { fail = fail + 1; print("FAIL iso len"); };
    if str_char_at(now, 4) != 45 { fail = fail + 1; print("FAIL iso dash1"); };
    if str_char_at(now, 7) != 45 { fail = fail + 1; print("FAIL iso dash2"); };
    if str_char_at(now, 10) != 84 { fail = fail + 1; print("FAIL iso T"); };
    if str_char_at(now, 13) != 58 { fail = fail + 1; print("FAIL iso colon1"); };
    if str_char_at(now, 16) != 58 { fail = fail + 1; print("FAIL iso colon2"); };
    if str_char_at(now, 19) != 90 { fail = fail + 1; print("FAIL iso Z"); };

    // HashMap iteration: keys + values come back in matching order.
    let m: i64 = hashmap_new();
    hashmap_insert(m, "alpha", 1);
    hashmap_insert(m, "beta", 2);
    hashmap_insert(m, "gamma", 3);
    let keys: Vec<i32> = hashmap_keys(m);
    let vals: Vec<i32> = hashmap_values(m);
    if vec_len(keys) != 3 { fail = fail + 1; print("FAIL keys len"); };
    if vec_len(vals) != 3 { fail = fail + 1; print("FAIL vals len"); };
    // Sum of values should be 1+2+3 = 6 regardless of iteration order.
    if vec_sum_i64(vals) != 6 { fail = fail + 1; print("FAIL vals sum"); };

    if fail == 0 { print("OK time_and_hashmap_iter"); return 0; };
    return 1;
}
