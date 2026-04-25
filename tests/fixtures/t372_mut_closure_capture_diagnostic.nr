// t372_mut_closure_capture_diagnostic.nr — v0.3.96 negative regression fixture.
//
// Pre-v0.3.96, closures that mutated captured variables via assignment
// silently no-op'd — the assignment wrote to the closure's local copy
// of the captured value (loaded once at entry via __nucleor_capture_get)
// and never propagated back to the caller's scope. Programs using
// FnMut-style mutation in closures silently mis-computed.
//
// Post-v0.3.96: closure_collect_capture_stmt detects kind 21
// (assignment) where the LHS is a captured outer variable (kind 3
// var ref resolving in outer sym AND not a closure param) and emits
// a clear diagnostic.
//
// This fixture is intended to surface the diagnostic.

fn main() -> i64 {
    let mut total: i64 = 0;
    let inc = |n: i64| { total = total + n; };
    inc(5); inc(7);
    return total;
}
