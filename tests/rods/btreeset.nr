// rods/btreeset — verify rod wrapper
import "stdlib/rods/btreeset.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let s: i64 = bts_new();
    bts_insert(s, "zebra");
    bts_insert(s, "apple");
    bts_insert(s, "monkey");

    if bts_len(s) != 3 { fail = fail + 1; print("FAIL len"); };
    if bts_contains(s, "apple") != 1 { fail = fail + 1; print("FAIL contains"); };

    bts_remove(s, "monkey");
    if bts_len(s) != 2 { fail = fail + 1; print("FAIL after remove"); };

    bts_free(s);

    if fail == 0 { print("OK btreeset"); return 0; };
    return 1;
}
