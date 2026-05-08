// RFC-0062 G-6 Phase 3 — positive lock-in. `async_spawn` /
// `thread_spawn` / `conc_spawn` with a Sendable primitive arg
// (i64 / handle) compiles cleanly. SEND-G6-* codes only fire
// when the arg shape is HashMap/Cell/RefCell, a closure literal,
// a tuple with non-Sendable element, or an enum with a
// non-Sendable variant payload.

fn worker(n: i64) -> i64 {
    return n * 2;
}

fn main() -> i32 {
    let n: i64 = 7;
    let task: i64 = async_spawn(worker, n);
    return async_await(task) as i32;
}
