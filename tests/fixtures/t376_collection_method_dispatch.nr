// t376_collection_method_dispatch.nr — v0.3.100 regression fixture.
//
// Pins receiver-type-aware method dispatch for the collection
// family (HashMap/HashSet/BTreeMap/BTreeSet/VecDeque). Pre-v0.3.100
// the kind-8 lowering fallback was always `vec_<method>`, so a
// Rust-style `m.insert(k, v)` on a `HashMap<str, i64>` lowered to
// `vec_insert(m, k, v)` — undefined symbol at clang link, hard
// adoption blocker for anyone reaching for the standard collection
// API. The lowercase runtime helpers (`hashmap_insert` etc.) all
// existed; this is the missing surface-level dispatch from the
// `let m: HashMap<...>` type annotation through `expr_struct_type`
// to the right helper prefix.
//
// Returns 30 = 10 + 20 from a HashMap insert/get round-trip,
// proving the receiver-type prefix is `hashmap_` (not `vec_`).

fn main() -> i64 {
    let mut m: HashMap<str, i64> = HashMap::new();
    m.insert("a", 10);
    m.insert("b", 20);
    return m.get("a") + m.get("b");
}
