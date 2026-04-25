// t390_nested_closure_capture.nr — v0.3.113 regression fixture.
//
// Pins capture propagation across nested closure literals. v0.3.107
// fixed the id-collision (both got `__closure_0`); this ship fixes
// the related capture-propagation bug. Pre-v0.3.113, the outer
// closure's capture-collect ignored inner closure literals entirely
// (no `kind == 42` case in `closure_collect_capture_expr`). When
// the inner closure referenced a name that ONLY existed in the
// caller's (e.g. main's) scope, outer never captured that name —
// so when inner's lowering queried outer's `clo_sym` for it, it
// wasn't there, inner emitted `@<name>` global refs, and clang
// link failed (`use of undefined value '@n'`).
//
// Fix: in `closure_collect_capture_expr`, walk inner-closure-literal
// bodies recursively, treating inner's params as the shadow set so
// inner-bound names don't bubble up. Names that resolve in the
// outer's caller-scope sym become outer's captures, which then
// re-propagate to inner via the existing param→capture wiring at
// inner's own lowering time.
//
// Returns 112 = 5 + 100 + 7, proving the inner closure correctly
// reads `n` (captured by outer from main, then by inner from outer)
// and `x` (outer's param captured by inner) alongside its own
// param `y`.

fn main() -> i64 {
    let n: i64 = 100;
    let outer = |x: i64| -> i64 {
        let f = |y: i64| -> i64 { return y + n + x; };
        return f(5);
    };
    return outer(7);
}
