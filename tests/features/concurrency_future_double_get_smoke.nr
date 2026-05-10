// F-CONC-002: thread_future_get double-consume must not double-free.
//
// Pre-fix, the first get freed the Future allocation and the second get
// touched freed memory, crashing on Windows heap fast-fail or libc abort.
// The fixed runtime keeps a consumed flag readable and returns 0 on a
// second consume.

import "stdlib/rods/thread.nr"

fn future_payload(x: i64) -> i64 {
    return x + 35;
}

fn main() -> i64 {
    let pool: i64 = thread_pool_new(1);
    if pool == 0 { return 1; };

    let fut: i64 = thread_pool_submit(pool, future_payload, 7);
    if fut == 0 { thread_pool_free(pool); return 2; };

    let first: i64 = thread_future_get(fut);
    let second: i64 = thread_future_get(fut);

    thread_pool_free(pool);

    if first != 42 { return 4; };
    if second != 0 { return 8; };
    return 0;
}
