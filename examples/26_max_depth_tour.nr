//! `#[max_depth]` tour.
//!
//! Single runnable program exercising the static-prover-accepted
//! recursion shape with a generous budget. Compile with
//! `nuc build examples/26_max_depth_tour.nr` and run; prints 2 OK lines
//! and exits 0.
//!
//! Demonstrates accepted recursion shapes with explicit maximum depth.

/// Canonical shape: counter named `depth` as first parameter, +1 per call.
/// Generous max_depth so the runtime per-fn TLS counter has headroom.
#[max_depth = 32]
fn power_of_two(depth: i64, n: i64) -> i64 {
    if depth >= 8 { return n; };
    return power_of_two(depth + 1, n * 2);
}

/// Parameter-flow shape: bounded counter is the second parameter, not
/// the first; not named `depth`.
#[max_depth = 32]
fn accumulate_until(acc: i64, remaining: i64) -> i64 {
    if remaining <= 0 { return acc; };
    return accumulate_until(acc + 1, remaining - 1);
}

fn main() -> i32 {
    let p: i64 = power_of_two(0, 1);
    if p != 256 { return 1; };
    print("OK 26_max_depth_tour: power_of_two = 256");

    let a: i64 = accumulate_until(10, 4);
    if a != 14 { return 2; };
    print("OK 26_max_depth_tour: accumulate_until = 14");

    return 0;
}
