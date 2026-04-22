// rods/hashmap_str — verify the rod-level wrapper
import "stdlib/rods/hashmap_str.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let m: i64 = hms_new();
    if hms_is_empty(m) != 1 { fail = fail + 1; print("FAIL empty"); };

    hms_insert(m, "alpha", 1);
    hms_insert(m, "beta", 2);
    hms_insert(m, "gamma", 3);
    if hms_len(m) != 3 { fail = fail + 1; print("FAIL len 3"); };

    if hms_get(m, "beta") != 2 { fail = fail + 1; print("FAIL get beta"); };
    if hms_contains(m, "missing") != 0 { fail = fail + 1; print("FAIL contains missing"); };

    if hms_get_or(m, "missing", 99) != 99 { fail = fail + 1; print("FAIL get_or default"); };
    if hms_get_or(m, "alpha", 99) != 1 { fail = fail + 1; print("FAIL get_or present"); };

    hms_remove(m, "beta");
    if hms_len(m) != 2 { fail = fail + 1; print("FAIL after remove"); };

    hms_free(m);

    if fail == 0 { print("OK hashmap_str"); return 0; };
    return 1;
}
