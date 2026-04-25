// T3.12 (v0.3.20) per-fn #[allow_fn] fixture. Two #[deadline]
// fns that would each fire warning[RT-007] (deadline without
// no_alloc/no_panic) under the v0.3.3 cross-check. The second
// has #[allow_fn(RT-007)] attached, so RT-007 should fire ONLY
// for the first. Verify gate asserts:
//   * RT-007 message contains "unguarded_one"
//   * RT-007 message does NOT contain "unguarded_two"

#[deadline = 1000]
fn unguarded_one(x: i64) -> i64 {
    return x + 1;
}

#[deadline = 1000]
#[allow_fn(RT-007)]
fn unguarded_two(x: i64) -> i64 {
    return x + 2;
}

fn main() -> i64 {
    return unguarded_one(0) + unguarded_two(0);
}
