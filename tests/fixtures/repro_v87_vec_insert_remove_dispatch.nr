// repro_v87_vec_insert_remove_dispatch.nr — v0.4.87 dispatch-name
// drift fix. Pre-fix `v.insert(idx, val)` lowered to runtime
// `vec_insert(...)` but no such helper exists; the actual helper
// is `vec_insert_at`. Same for `v.remove(idx)` → `vec_remove_at`.
// Pre-fix both failed at clang link with `undefined value
// '@vec_insert' / '@vec_remove'`. Discovered as a sister bug
// while shipping v0.4.86's narrow-RHS check for `.insert/.set`.
//
// v0.4.87 aliases `insert` → `insert_at` and `remove` → `remove_at`
// at method dispatch.
//
// EXPECT: build succeeds + runtime output `1 99 1 2` (after
// push 1/2/3 then insert(1,99) → [1,99,2,3]; print v[0]=1, v[1]=99;
// then remove(1) → [1,2,3]; print v[0]=1, v[1]=2).

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1); v.push(2); v.push(3);
    v.insert(1, 99);
    println!("{}", v[0]);
    println!("{}", v[1]);
    v.remove(1);
    println!("{}", v[0]);
    println!("{}", v[1]);
    return 0;
}
