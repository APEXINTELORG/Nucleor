// t455_hashmap_contains_method_dispatch.nr -- v0.3.190 regression
// fixture.
//
// Two related bugs fixed:
// 1. `h.contains_key(k)` (canonical Rust name) lowered to
//    `hashmap_contains_key` which did not exist in the runtime
//    -> link error.
// 2. `h.contains(k)` for HashMap silently dispatched to the
//    Vec method `vec_contains_i64` (because iter_method_for_vec
//    matched "contains" without checking receiver type), so
//    HashMap.contains(key) ALWAYS returned false even on
//    present keys -- silent miscompute.
//
// Same hazard class as v0.3.143/163/164/178/181/182 -- adopter
// canonical pattern produces wrong answer with no diagnostic.
//
// Fix (v0.3.190):
// 1. New runtime aliases __nucleor_hashmap_contains_key /
//    __nucleor_btreemap_contains_key (both delegate to
//    *_contains). Compiler get_rt_name + declare list
//    extended.
// 2. Method-dispatch site at line 11581: only fire
//    iter_method_for_vec when receiver IS a Vec (or unknown
//    type). For HashMap/HashSet/BTreeMap/etc receivers, fall
//    through to v0.3.100 receiver-type-aware dispatch.

fn main() -> i64 {
    let mut h: HashMap<str, i64> = HashMap::new();
    h.insert("a", 1);
    h.insert("b", 2);
    let mut sum: i64 = 0;
    if h.contains("a") { sum = sum + 100; };       // pre-fix false
    if h.contains_key("b") { sum = sum + 10; };    // pre-fix link error
    if h.contains("z") { sum = sum + 1; };          // not present
    if sum != 110 { return 1; };

    // Vec.contains still works (preserves backward compat).
    let mut v: Vec<i64> = Vec::new();
    v.push(1); v.push(2); v.push(3);
    if v.contains(2) == 0 { return 2; };
    return 42;
}
