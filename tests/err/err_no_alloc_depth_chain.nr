// EXPECT: error[RT-001]
// v0845 Lane 3 / Queue 3C — 7-hop transitive chain to Vec::new()
// across module boundary. Pre-v0845 the no_alloc caller-closure
// depth=4 caused chains of 5..=7 hops to silently pass the build;
// v0845 raised the bound to 8 (matching restricts and requires-row),
// so this fixture now surfaces RT-001 transitive.

import "err_no_alloc_depth_chain_aux.nr"

#[no_alloc]
fn caller() -> i32 {
    aux_hop1()
}

fn main() -> i32 {
    caller()
}
