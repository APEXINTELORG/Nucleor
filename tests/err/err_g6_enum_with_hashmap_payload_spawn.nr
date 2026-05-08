// EXPECT: SEND-G6-ENUM non-Sendable variant payload
// RFC-0062 G-6 Phase 3 — Sendable per-call-site classification.
// An enum is Sendable iff every variant's payload types are
// Sendable. An enum binding whose enum has at least one variant
// payload containing HashMap / Cell / RefCell fires
// SEND-G6-ENUM when passed to a spawn-family call.

enum Payload {
    Empty,
    WithMap(HashMap<str, i64>),
}

fn worker(p: Payload) -> i64 {
    return 0;
}

fn main() -> i32 {
    let p: Payload = Payload::Empty;
    let task: i64 = async_spawn(worker, p);
    return async_await(task) as i32;
}
