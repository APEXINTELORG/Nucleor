// RFC-0062 G-11 Phase 2b — `let mut x: i64;` followed by an
// assignment that dominates the read is permitted by the
// definite-assignment flow analysis. Pre-Phase-2b TYP-008 rejected
// this shape unconditionally; post-Phase-2b TYP-008 narrows to
// immutable no-init only, and INIT-G11-READ-BEFORE-INIT takes over
// the runtime-soundness role for mutable bindings — which doesn't
// fire here because the assignment dominates the read.
//
// Was: tests/err/err_g11_uninit_simple.nr (Phase 1 lock-in).
fn main() -> i64 {
    let mut x: i64;
    x = 7;
    return x;
}
