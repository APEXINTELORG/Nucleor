// btreemap_basic.nr — RFC-0017 phase 3: ordered associative map
// Sorted by key; iteration via key_at/val_at yields sorted order.

extern fn str_eq(a: str, b: str) -> i64;

fn main() -> i32 {
    let mut fail: i64 = 0;

    let m: i64 = btreemap_new();
    if btreemap_len(m) != 0 { fail = fail + 1; print("FAIL: empty len\n"); };

    // Insert in random order
    btreemap_insert(m, "charlie", 3);
    btreemap_insert(m, "alice", 1);
    btreemap_insert(m, "bob", 2);
    btreemap_insert(m, "delta", 4);
    if btreemap_len(m) != 4 { fail = fail + 1; print("FAIL: len after inserts\n"); };

    // get returns correct value
    if btreemap_get(m, "alice") != 1 { fail = fail + 1; print("FAIL: get alice\n"); };
    if btreemap_get(m, "delta") != 4 { fail = fail + 1; print("FAIL: get delta\n"); };
    if btreemap_get(m, "missing") != 0 { fail = fail + 1; print("FAIL: get missing\n"); };

    // contains
    if btreemap_contains(m, "bob") != 1 { fail = fail + 1; print("FAIL: contains bob\n"); };
    if btreemap_contains(m, "ghost") != 0 { fail = fail + 1; print("FAIL: contains ghost\n"); };

    // ORDERED iteration: positions yield sorted keys
    // alice < bob < charlie < delta
    if btreemap_val_at(m, 0) != 1 { fail = fail + 1; print("FAIL: pos 0 val (alice=1)\n"); };
    if btreemap_val_at(m, 1) != 2 { fail = fail + 1; print("FAIL: pos 1 val (bob=2)\n"); };
    if btreemap_val_at(m, 2) != 3 { fail = fail + 1; print("FAIL: pos 2 val (charlie=3)\n"); };
    if btreemap_val_at(m, 3) != 4 { fail = fail + 1; print("FAIL: pos 3 val (delta=4)\n"); };

    // Update existing
    btreemap_insert(m, "alice", 100);
    if btreemap_get(m, "alice") != 100 { fail = fail + 1; print("FAIL: alice updated\n"); };
    if btreemap_len(m) != 4 { fail = fail + 1; print("FAIL: len unchanged on update\n"); };

    // Remove maintains sorted order
    btreemap_remove(m, "bob");
    if btreemap_len(m) != 3 { fail = fail + 1; print("FAIL: len after remove\n"); };
    if btreemap_val_at(m, 1) != 3 { fail = fail + 1; print("FAIL: pos 1 after remove (charlie=3)\n"); };

    btreemap_clear(m);
    if btreemap_len(m) != 0 { fail = fail + 1; print("FAIL: cleared\n"); };

    btreemap_free(m);

    if fail == 0 { print("OK btreemap_basic\n"); return 0; };
    return 1;
}
