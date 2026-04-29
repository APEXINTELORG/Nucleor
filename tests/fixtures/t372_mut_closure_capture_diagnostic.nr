// t372_mut_closure_capture_diagnostic.nr — FnMut capture writeback fixture.
//
// Pre-v0.3.96, closures that mutated captured variables via assignment
// silently no-op'd — the assignment wrote to the closure's local copy
// of the captured value (loaded once at entry via __nucleor_capture_get)
// and never propagated back to the caller's scope. Programs using
// FnMut-style mutation in closures silently mis-computed.
//
// v0.4.110: assignment writes through to the capture table, and direct
// closure-variable calls refresh the caller's captured locals.

fn main() -> i64 {
    let mut total: i64 = 0;
    let inc = |n: i64| { total = total + n; };
    inc(5); inc(7);
    return total;
}
