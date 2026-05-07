// v0845 Lane 3 / Queue 3C — auxiliary lib for the depth=8 chain
// regression fixtures. Skipped from standalone iteration via the
// `_aux.nr$` regex in `tools/verify.sh` (TEST_SKIP_REGEX).
//
// Provides a 7-deep un-rowed chain (hop1 → hop2 → ... → hop7) that
// terminates in a Vec::new() allocation. Pre-v0845 the no_alloc
// caller-closure depth was 4 hops, so chains of 5..=7 reachers fell
// silently through the bound. v0845 raised the bound to 8 to match
// `restricts_transitive_check` and the v0845 lane 2 requires-row
// depth.

fn aux_alloc_leaf() -> i32 { let _v: Vec<i32> = Vec::new(); return 0; }
fn aux_hop7() -> i32 { aux_alloc_leaf() }
fn aux_hop6() -> i32 { aux_hop7() }
fn aux_hop5() -> i32 { aux_hop6() }
fn aux_hop4() -> i32 { aux_hop5() }
fn aux_hop3() -> i32 { aux_hop4() }
fn aux_hop2() -> i32 { aux_hop3() }
fn aux_hop1() -> i32 { aux_hop2() }
