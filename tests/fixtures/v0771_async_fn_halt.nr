// v0.7.71 negative fixture — Rust `async fn` halt.
// Pre-fix `async` was silently stripped, the fn parsed as a regular
// synchronous fn, and `let r = fetch();` returned the inner value
// directly (rc=42) instead of a `Future<Output = i64>` to `.await`.
// Now halts at parse with workaround pointer (drop `async` + use
// existing thread/queue substrate for concurrency).
async fn fetch() -> i64 {
    return 42;
}

fn main() -> i64 {
    let r: i64 = fetch();
    return r;
}
