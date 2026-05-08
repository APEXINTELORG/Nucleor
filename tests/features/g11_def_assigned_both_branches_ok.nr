// RFC-0062 G-11 Phase 2b — both arms of an if/else assign the
// binding before the post-join read. The DA flow analysis
// intersects __init_* keys at the merge point: both 1 → state 1
// (definitely assigned), and the read is sound. No diagnostic
// fires.
//
// Pre-Phase-2b: TYP-008 rejected this shape unconditionally
// because Nucleor lacked flow-sensitive analysis. Phase 2b adds
// the analysis (own_merge_moved extended to intersect __init_*
// keys). This fixture locks the new behavior.
//
// Was: tests/err/err_g11_uninit_branch.nr (Phase 1 lock-in).
fn main() -> i64 {
    let mut cls: i64;
    if true {
        cls = 1;
    } else {
        cls = 2;
    }
    return cls;
}
