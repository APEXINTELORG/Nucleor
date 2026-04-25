// t393_vec_with_capacity.nr — v0.3.116 regression fixture.
//
// Pins `Vec::with_capacity(N)`. Pre-v0.3.116, the kind-12
// associated-fn-call lowering only handled `Vec::new` for the
// generic Vec — `Vec::with_capacity(N)` fell through to the
// diagnostic+zero path. Adopters reaching for the canonical Rust
// pre-allocation pattern (for known-size accumulators that want to
// avoid realloc churn during many push calls) saw the .exe return
// 0 from the constructor and every subsequent push silently fail.
//
// Three-piece fix:
//   1. Runtime: new `__nucleor_vec_with_capacity(n)` mirrors
//      `__nucleor_vec_new` but allocates `max(n, 4)` slots upfront.
//   2. Compiler: kind-12 dispatch handles `Vec::with_capacity`,
//      lowering the single arg and calling `vec_with_capacity`.
//      Registered in get_rt_name + is_ptr_ret + IR header declare.
//      Mirrored in nucleor_tools_suite.nr.
//   3. helper_manifest.toml regenerated.
//
// Returns 1 (the post-push len) — proves the pre-allocated Vec
// is push-able and len reflects the pushed element count, not
// the reserved capacity.

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::with_capacity(100);
    v.push(42);
    return v.len();
}
