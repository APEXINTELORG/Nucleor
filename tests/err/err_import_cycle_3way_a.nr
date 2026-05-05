// EXPECT: error[MOD-005]
// v0.8.301 R12-D7 Phase 1.5 — 3-way A->B->C->A cycle exercises
// the v0.8.294 MOD-005 detector at greater depth.
import "err_import_cycle_3way_b.nr"

fn main() -> i32 {
    return 0;
}
