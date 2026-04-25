// T3.17 (v0.3.32) — proves v0.3.20's #[allow_fn(CODE)] works
// for RT-004 (the static WCET v1 warning). v0.3.31's RT-004
// message text advertises #[allow_fn(RT-004)] as the per-fn
// opt-out; this fixture closes the coverage gap left by T3.12
// (which only exercised allow_fn for RT-007).
//
// Two #[deadline = 1]-marked fns. Both bodies are identical
// thousand-iteration loops that the v1 estimator scores as
// 60us (well over the 1us budget). The first fires RT-004; the
// second has #[allow_fn(RT-004)] and stays silent.
//
// Verify gate (T3.17) asserts:
//   * RT-004 fires exactly ONCE (proves the suppression
//     dropped one diagnostic, not all or none — matches the
//     T3.12 pattern for RT-007).

#[deadline = 1]
fn would_overrun(x: i64) -> i64 {
    let mut i: i64 = 0;
    let mut acc: i64 = 0;
    while i < 1000 {
        acc = acc + x + i;
        i = i + 1;
    };
    return acc;
}

#[deadline = 1]
#[allow_fn(RT-004)]
fn would_overrun_silenced(x: i64) -> i64 {
    let mut i: i64 = 0;
    let mut acc: i64 = 0;
    while i < 1000 {
        acc = acc + x + i;
        i = i + 1;
    };
    return acc;
}

fn main() -> i64 {
    return 0;
}
