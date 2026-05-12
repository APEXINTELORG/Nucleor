// v0.8.79 T-4 hole canary fixture (no compiler edit).
//
// This fixture documents the TODAY state of RFC T-4 empty-type
// compatibility hole as a regression canary:
//
//   `vec_get` returns an "" empty-type sentinel; `types_compatible`
//   short-circuits to true for any expected type → silent
//   miscompute. `let v: i64 = vec_get(xs, 0)` builds clean and
//   stores the actual element value (correct here), but the
//   same shape `let b: bool = vec_get(xs_i64, 0)` also builds
//   clean and silently stores the i64 in a bool binding.
//
// This fixture exercises the WELL-TYPED path (i64 = vec_get on
// Vec<i64>) which currently produces correct runtime behavior.
// rc = 10 + 20 + 30 - 50 = 10.
//
// Inversion protocol when Phase 2b NUC_STRICT_INFERENCE lands:
// in default-off mode this fixture continues to compile + run
// with rc=10. A SISTER fixture under tests/err/ should then be
// added EXPECT'ing TYP-027 for the mistyped shape (`let b: bool
// = vec_get(xs_i64, 0)`) under NUC_STRICT_INFERENCE=1. Phase 4
// makes strict the default; the well-typed fixture remains.

fn main() -> i64 {
    let mut xs: Vec<i64> = Vec::new();
    xs.push(10);
    xs.push(20);
    xs.push(30);
    let a: i64 = vec_get(&xs, 0);
    let b: i64 = vec_get(&xs, 1);
    let c: i64 = vec_get(&xs, 2);
    return a + b + c - 50;
}
