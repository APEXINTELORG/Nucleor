// RFC-0062 G-3 Phase 3 — positive lock-in. `hashmap_insert` /
// `hashmap_remove` / `hashmap_clear` is fine when no live shared
// borrow of the same map binding exists. ALIAS-G3-HASHMAP-REHASH
// only fires when own_has_shared_overlap reports a live borrow
// on the binding at the mutation call site.

fn main() -> i32 {
    let mut m: HashMap<str, i64> = HashMap::new();
    hashmap_insert(m, "k", 1);
    hashmap_insert(m, "k2", 2);
    let n: i64 = hashmap_len(m);
    print_int(n as i32);
    0
}
