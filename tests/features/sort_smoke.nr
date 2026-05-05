// v0.8.165 stdlib/rods/sort.nr first test coverage.
//
// Insertion sort + str cmp + sort_by parallel keys + is_sorted
// predicate. Pre-v0.8.165: zero coverage on the sort rod.
//
// Locks five textbook sort invariants:
//   1. **Reverse-sorted ints**: [5,4,3,2,1] → [1,2,3,4,5].
//   2. **Already-sorted ints**: [1,2,3] is_sorted == 1.
//   3. **Random ints + is_sorted**: [3,1,4,1,5,9,2,6] sorted →
//      is_sorted==1; pre-sort is_sorted==0.
//   4. **String cmp triple**: cmp("a","b") < 0; cmp("b","a") > 0;
//      cmp("ab","ab") == 0; cmp("ab","abc") < 0.
//   5. **sort_by parallel keys**: values=[10,20,30], keys=[3,1,2]
//      → values reorder to [20,30,10] (ascending key order).
//
// Expected: rc=0.

import "stdlib/rods/sort.nr"

fn check_reverse_sort() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(5); v.push(4); v.push(3); v.push(2); v.push(1);
    sort_ints(v);
    if v.get(0) != 1 { return 1; };
    if v.get(1) != 2 { return 2; };
    if v.get(2) != 3 { return 4; };
    if v.get(3) != 4 { return 8; };
    if v.get(4) != 5 { return 16; };
    return 0;
}

fn check_is_sorted() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(1); v.push(2); v.push(3);
    if is_sorted(v) != 1 { return 32; };
    let mut u: Vec<i32> = Vec::new();
    u.push(3); u.push(1); u.push(4); u.push(1); u.push(5); u.push(9); u.push(2); u.push(6);
    if is_sorted(u) != 0 { return 64; };
    sort_ints(u);
    if is_sorted(u) != 1 { return 128; };
    return 0;
}

fn check_str_cmp() -> i64 {
    if sort_str_cmp("a", "b") >= 0 { return 256; };
    if sort_str_cmp("b", "a") <= 0 { return 512; };
    if sort_str_cmp("ab", "ab") != 0 { return 1024; };
    if sort_str_cmp("ab", "abc") >= 0 { return 2048; };
    return 0;
}

fn check_sort_by_parallel_keys() -> i64 {
    let mut vals: Vec<i32> = Vec::new();
    vals.push(10); vals.push(20); vals.push(30);
    let mut keys: Vec<i32> = Vec::new();
    keys.push(3); keys.push(1); keys.push(2);
    sort_by(vals, keys);
    // After sort: keys [1,2,3], vals [20,30,10]
    if vals.get(0) != 20 { return 4096; };
    if vals.get(1) != 30 { return 8192; };
    if vals.get(2) != 10 { return 16384; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_reverse_sort();
    fails = fails + check_is_sorted();
    fails = fails + check_str_cmp();
    fails = fails + check_sort_by_parallel_keys();
    return fails;
}
