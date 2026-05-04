// v0.8.76 RFC-0062 G-3 Phase 2b regression smoke. Locks the
// behavior of the v0.8.74 dataflow handoff detection + v0.8.75
// unconditional flip.
//
// Pre-v0.8.74: under the v0.8.65 flip experiment, this test
// returned rc=0 (registry was empty/dangling — auto-drop
// freed the local Vec before the caller could read from
// registry). That was the load-bearing memory-safety bug.
//
// Post-v0.8.74 (unconditional flip in v0.8.75): handoff
// dataflow detection sees `vec_push(reg, local)`, suppresses
// auto-drop on `local` at fn exit. Registry retains the
// pushed Vec. vec_len returns 1.
//
// Expected: rc=1 (registry has 1 element).
//
// If this fixture EVER returns rc=0 again, the handoff
// suppression has regressed and the unconditional default-flip
// is unsafe.

fn build_into(reg: Vec<i32>) -> i64 {
    let mut local: Vec<i32> = Vec::new();
    local.push(99);
    vec_push(reg, local);   // handoff: detected, auto-drop suppressed
    return 0;
}

fn main() -> i64 {
    let mut registry: Vec<i32> = Vec::new();
    build_into(registry);
    return vec_len(&registry);   // expected: 1
}
