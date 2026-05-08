// EXPECT: SEND-G6-HASHMAP non-Sendable container type
// RFC-0062 G-6 Phase 3 — Sendable per-call-site classification.
// HashMap<K,V> is not yet audited as Sendable (K, V, and the
// hasher must each be Sendable). Spawning a worker fn with a
// HashMap argument crosses a thread boundary with non-Sendable
// state; SEND-G6-HASHMAP fires at the spawn call site.
fn worker(m: HashMap<str, i64>) -> i64 {
    return hashmap_len(m);
}

fn main() -> i32 {
    let m: HashMap<str, i64> = HashMap::new();
    let task: i64 = async_spawn(worker, m);
    return async_await(task) as i32;
}
