// v0.8.77 RFC-0062 G-3 — hashmap_insert handoff coverage.
// Sister of v0876 vec_push test. Uses hashmap_insert(map, key,
// value) where value is a local Vec — same handoff pattern,
// detected by v0.8.74 dataflow at value arg index 2.
//
// Expected: rc=42 (sentinel — the actual handoff result is
// hard to verify without specific HashMap inspection; this
// fixture mainly verifies the build doesn't dangle/segfault).

fn build_into_map(m: HashMap<str, Vec<i32>>) -> i64 {
    let mut local: Vec<i32> = Vec::new();
    local.push(7);
    hashmap_insert(m, "key", local);  // handoff detected; auto-drop suppressed
    return 0;
}

fn main() -> i64 {
    let mut m: HashMap<str, Vec<i32>> = HashMap::new();
    build_into_map(m);
    return 42;
}
