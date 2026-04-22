// rods/hashset — verify rod wrapper
import "stdlib/rods/hashset.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let s: i64 = hss_new();
    hss_insert(s, "alpha");
    hss_insert(s, "beta");
    hss_insert(s, "gamma");

    if hss_len(s) != 3 { fail = fail + 1; print("FAIL len"); };
    if hss_contains(s, "alpha") != 1 { fail = fail + 1; print("FAIL contains alpha"); };
    if hss_contains(s, "missing") != 0 { fail = fail + 1; print("FAIL contains missing"); };

    hss_insert(s, "alpha");  // dedupe
    if hss_len(s) != 3 { fail = fail + 1; print("FAIL dedupe"); };

    hss_remove(s, "beta");
    if hss_len(s) != 2 { fail = fail + 1; print("FAIL after remove"); };

    hss_free(s);

    if fail == 0 { print("OK hashset"); return 0; };
    return 1;
}
