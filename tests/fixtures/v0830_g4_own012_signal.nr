// v0.8.30 RFC-0062 G-4 Phase 2a signal fixture — exercises
// `vec_free` and `hashmap_free` to ensure the OWN-012 audit-pass
// info fires on a build with explicit frees.
//
// Build emits `info[OWN-012]: explicit free calls present in
// build: N` (N=2). rc=15.

fn main() -> i64 {
    let v: Vec<i64> = Vec::new();
    let mut m: HashMap<str, i64> = HashMap::new();
    m.insert("k", 7);
    let n: i64 = hashmap_len(&m);  // 1
    vec_free(v);
    hashmap_free(m);
    return n + 14;  // 15
}
