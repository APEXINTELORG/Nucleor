// t394_collection_with_capacity.nr — v0.3.117 regression fixture.
//
// Pins `with_capacity(N)` constructors for the collection family
// (HashMap, HashSet, VecDeque, String). Pre-v0.3.117, only
// `Vec::with_capacity` was wired (added in v0.3.116) — every other
// collection's `with_capacity` fell through to the diagnostic+zero
// path, returning a zero handle and silently breaking subsequent
// inserts/pushes.
//
// BTreeMap/BTreeSet are intentionally NOT in the dispatch — they're
// trees not flat arrays at the runtime level, so capacity has no
// meaning and no helper exists. Adopters reaching for those should
// use `BTreeMap::new()`. Vec already shipped in v0.3.116.
//
// Returns 1 — proves HashMap::with_capacity returns a usable handle
// that accepts an insert and reports len = 1 (not 0 from a zero
// placeholder).

fn main() -> i64 {
    let mut m: HashMap<str, i64> = HashMap::with_capacity(100);
    m.insert("k", 42);
    return m.len();
}
