// EXPECT: SEND-G6-TUPLE non-Sendable element
// RFC-0062 G-6 Phase 3 — Sendable per-call-site classification.
// A tuple is Sendable iff every element type is Sendable. A
// tuple binding declared with at least one HashMap / Cell /
// RefCell element fires SEND-G6-TUPLE when passed to a
// spawn-family call.
fn worker(payload: (i64, HashMap<str, i64>)) -> i64 {
    return 0;
}

fn main() -> i32 {
    let m: HashMap<str, i64> = HashMap::new();
    let payload: (i64, HashMap<str, i64>) = (1, m);
    let task: i64 = async_spawn(worker, payload);
    return async_await(task) as i32;
}
