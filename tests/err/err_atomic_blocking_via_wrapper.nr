// EXPECT: ATOMIC-001
//
// Lane 6 / F-CONC-005 (audit 2026-05-08): the `#[atomic]` blocking
// scanner now recognises the friendly rod-level wrapper names
// (`conc_lock`, `conc_recv`, etc.). Pre-fix the single-hop substring
// check only matched the underlying primitive (`mutex_lock`,
// `channel_recv`) and missed every wrapper call shape.
#[atomic]
fn bad_via_wrapper() -> i64 {
    conc_lock(0);
    return 0;
}

fn main() -> i64 {
    return bad_via_wrapper();
}
