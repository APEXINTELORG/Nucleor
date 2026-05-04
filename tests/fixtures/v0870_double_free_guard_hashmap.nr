// v0.8.70 RFC-0062 G-4 Phase 2b — HashMap double-free guard smoke.
// Sister of v0870_double_free_guard_vec.nr. Run under
// NUC_VEC_FREE_GUARD=1: triggers PANIC-DOUBLE-FREE + exit 134.

fn main() -> i64 {
    let mut m: HashMap<str, i64> = HashMap::new();
    m.insert("k", 1);
    hashmap_free(m);
    hashmap_free(m);  // double free — guard catches under env var
    return 0;          // unreachable under guard
}
