// EXPECT: error[MOD-005]
// v0.8.294 R12-D7 Phase 1 — A->B->A import cycle.
// A imports B, B imports A. Pre-v0.8.294 the resolver dedup'd
// silently. Post-v0.8.294 emits error[MOD-005] with cycle path.
import "err_import_cycle_mod005_b.nr"

fn main() -> i32 {
    return 0;
}
