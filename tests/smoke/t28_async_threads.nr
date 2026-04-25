// T2.8 (v0.2.353) smoke: async runtime — threads-only.
// `async fn`, `async_spawn`, `<ident>.await` are all syntactic sugar
// over the existing thread runtime (CreateThread / pthread_create).
// Per the locked v0.2 design vote: every async fn = a real OS thread.

async fn square(x: i64) -> i64 {
    return x * x;
}

async fn add_one(x: i64) -> i64 {
    return x + 1;
}

#[test]
fn test_async_basic_spawn_await() {
    let h: i64 = async_spawn(square, 7);
    let r: i64 = h.await;
    assert_eq(r, 49);
}

#[test]
fn test_async_two_concurrent_tasks() {
    // Spawn two tasks, await both. Order doesn't matter — both
    // complete and the captured results round-trip i64 cleanly.
    let h1: i64 = async_spawn(square, 5);
    let h2: i64 = async_spawn(add_one, 10);
    let r1: i64 = h1.await;
    let r2: i64 = h2.await;
    assert_eq(r1, 25);
    assert_eq(r2, 11);
}

#[test]
fn test_async_await_in_arithmetic() {
    let h1: i64 = async_spawn(square, 3);
    let h2: i64 = async_spawn(square, 4);
    // .await rewrites to async_await(<ident>) — usable wherever
    // an i64 expression is.
    let total: i64 = h1.await + h2.await;
    assert_eq(total, 25);
}

#[test]
fn test_async_zero_arg_fn() {
    let h: i64 = async_spawn(square, 0);
    assert_eq(h.await, 0);
}
