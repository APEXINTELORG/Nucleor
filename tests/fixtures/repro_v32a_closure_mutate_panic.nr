// v0.4.32a silent-miscompute closure: closure that mutates a captured
// outer variable used to compile cleanly but the mutation silently
// no-op'd at runtime (the closure mutated its local copy). Now panics.
// EXPECT: panic
fn main() -> i64 {
    let mut total: i64 = 0;
    let inc = |x: i64| {
        total = total + x;  // mutate captured var — was silent miscompute
    };
    inc(5);
    return total;
}
