// EXPECT: ALIAS-G3-HASHMAP-REHASH hashmap_insert
// RFC-0062 G-3 Phase 3 — heap-aliasing per-fn analysis.
// `hashmap_insert` / `hashmap_remove` / `hashmap_clear` while a
// live shared borrow of the same map binding exists may rehash
// storage and invalidate the borrow. Fire ALIAS-G3-HASHMAP-REHASH
// at the mutation call site.
fn main() -> i32 {
    let mut m: HashMap<str, i64> = HashMap::new();
    let r: &HashMap<str, i64> = &m;
    hashmap_insert(m, "k", 1);
    0
}
