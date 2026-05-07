// EXPECT: error[EFF-001]
// v0845 Lane 2 / Queue 2A — cross-module 4-deep transitive chain.
// Pre-v0845 the requires transitive depth was 3 hops, so the chain
//   caller -> deep_hop1 -> deep_hop2 -> deep_hop3 -> deep_hop4 -> print
// fell silently through the bound (call to print is 5 hops from caller,
// 4 hops past unrowed_helper). v0845 raised the depth to 8 to match
// the restricts path; the silent fall-through now surfaces as EFF-001.

import "err_requires_cross_module_aux.nr"

fn caller() -> i32 requires [net] {
    deep_hop1()
}

fn main() -> i32 requires [net] {
    caller()
}
