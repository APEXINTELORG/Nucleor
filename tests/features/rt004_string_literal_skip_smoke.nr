// v0.8.291 R03-D3 Phase 1.5 — RT-004 estimator: string-literal +
// line-comment skip.
//
// Per audit `BUILD_PLAN_R03_realtime_determinism.md` §1 R03-D3 (MEDIUM):
// v0.8.289 doc-honesty pass renamed RT-004 from "static WCET" to
// "heuristic deadline estimate" but did NOT improve the estimator.
// User pushback (2026-05-05): "can this be fixed as opposed to just
// saying can't do it?" — yes, partially. v0.8.291 closes one of the
// named false-positive gaps: the estimator now SKIPS `;` inside `"`
// string literals (with `\\"` escape) and `//` line comments.
//
// What this fixture proves:
//   - A `#[deadline]` function whose body is dominated by `;`-loaded
//     string literals + commented-out code does NOT trip RT-004.
//
// Pre-v0.8.291: the body below scored ~10 stmt × multiplier and
// would over-trip the estimator vs declared 100us deadline if any
// loop were present.
// Post-v0.8.291: the body is one real `let s = "...";` plus a `//`
// comment; the scan tally is the single `;` after the let, well
// below 1000us.
//
// Acceptance: `nuc build` succeeds with no RT-004 warning.
// rc=0 from the runtime indicates compile-time RT-004 was not
// raised (build succeeded) AND the runtime printed our literal.
//
// Expected: rc=0; stdout contains "ok".

#[deadline = 1000us]
pure fn budget_friendly() -> i32 {
    // Pre-v0.8.291 the literal below over-counted 5 spurious `;` and
    // the comment text would have flagged a phantom `while`:
    //     while we wait for v0.8.291 to land
    let s: str = "a;b;c;d;e;";
    let _keep: str = s;
    0
}

fn main() -> i32 {
    let r: i32 = budget_friendly();
    if r == 0 {
        print("ok");
    } else {
        print("bad");
    };
    return 0;
}
