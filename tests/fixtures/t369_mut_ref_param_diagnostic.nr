// t369_mut_ref_param_diagnostic.nr — v0.3.93 negative regression fixture.
//
// Pre-v0.3.93, declaring a `&mut T` parameter silently passed by
// value, so any mutation via `*x = ...` was a no-op — the caller's
// variable was never modified. `add_one(&mut n)` returned without
// incrementing n, but compile and run succeeded.
//
// Post-v0.3.93: parse_fn_decl detects `&mut T` parameter types and
// emits a clear diagnostic naming the issue and the canonical
// workaround (return new value or use Vec<i64>).
//
// This fixture is intended to surface the diagnostic; the verify
// step asserts the diagnostic text appears.

fn add_one(x: &mut i64) {
    return;
}

fn main() -> i64 {
    return 0;
}
