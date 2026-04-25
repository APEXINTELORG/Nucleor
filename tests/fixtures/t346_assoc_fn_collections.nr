// t346_assoc_fn_collections.nr — v0.3.71 regression fixture.
//
// Pins Rust-style associated-fn alias compilation for the lowercase
// collection helpers. Pre-v0.3.71, every `HashMap::new()`/`HashSet::new()`/
// `BTreeMap::new()`/`BTreeSet::new()`/`VecDeque::new()` produced the
// "unhandled expr kind 12" error and broken `%r.-1` IR. v0.3.71 wires
// these to the existing `__nucleor_*_new` runtime helpers.
//
// Returns 1 + 2 + 4 + 8 + 16 = 31 if all five forms compile and call
// the right helper (each helper returns a non-null handle).

fn main() -> i64 {
    let mut score: i64 = 0;

    let m1: i64 = hashmap_new();      // baseline lowercase form
    if m1 != 0 { score = score + 1; };

    let m2: i64 = HashMap::new();     // v0.3.71 alias
    if m2 != 0 { score = score + 2; };

    let s1: i64 = HashSet::new();
    if s1 != 0 { score = score + 4; };

    let bm: i64 = BTreeMap::new();
    if bm != 0 { score = score + 8; };

    let bs: i64 = BTreeSet::new();
    if bs != 0 { score = score + 16; };

    return score;  // expect 31
}
