// rods/btreemap — verify rod wrapper + ordered iteration
import "stdlib/rods/btreemap.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let m: i64 = btm_new();
    btm_insert(m, "charlie", 3);
    btm_insert(m, "alpha", 1);
    btm_insert(m, "bravo", 2);
    if btm_len(m) != 3 { fail = fail + 1; print("FAIL len"); };

    // Sorted iteration: alpha, bravo, charlie
    if btm_val_at(m, 0) != 1 { fail = fail + 1; print("FAIL pos 0"); };
    if btm_val_at(m, 1) != 2 { fail = fail + 1; print("FAIL pos 1"); };
    if btm_val_at(m, 2) != 3 { fail = fail + 1; print("FAIL pos 2"); };

    if btm_get(m, "alpha") != 1 { fail = fail + 1; print("FAIL get"); };
    if btm_get_or(m, "missing", 42) != 42 { fail = fail + 1; print("FAIL get_or"); };

    btm_free(m);

    if fail == 0 { print("OK btreemap"); return 0; };
    return 1;
}
