// t356_indexed_lhs_diagnostic.nr — v0.3.124 positive regression fixture.
//
// Originally a v0.3.81 negative pin for the diag-only stub.
// v0.3.124 replaces the stub with real `v[i] = X` lowering to
// `vec_set(v, i, X)`.
//
// Timeline:
// - Pre-v0.3.81: compiler segfaulted on the kind-10 LHS path
//   (ACCESS_VIOLATION, exit -1073741819).
// - v0.3.81-v0.3.123: diag fired but build still produced a .exe
//   with the assignment SILENTLY DROPPED — read-back of v[i]
//   returned the original value (HIGH-blast silent miscompute
//   hidden behind an informational diag).
// - v0.3.124+: real lowering — assignment takes effect; read-back
//   returns the assigned X.
//
// Returns 999, proving the v[1] = 999 assignment actually mutates.

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(10); v.push(20); v.push(30);
    v[1] = 999;
    return v[1];
}
