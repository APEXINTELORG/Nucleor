// v0.7.8 (defensive halt): canonical Rust complex-receiver
// `.await` (`fetch().await`, `arr[0].await`,
// `expr.method().await`) pre-fix surfaced as wrong-class
// `cannot resolve field access .await` because the
// expand_async_await textual pass only matches the simple
// `<ident>.await` form. Now halts cleanly with a let-extract
// workaround pointer. Negative fixture (compile rejects).
fn fetch() -> i64 { return 42; }

fn main() -> i32 {
    let v: i64 = fetch().await;    // ← halts: complex-receiver .await unsupported
    print_int(v as i32);
    return 0;
}
