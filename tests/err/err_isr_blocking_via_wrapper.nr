// EXPECT: ATOMIC-001
//
// Lane 6 / F-CONC-005 (audit 2026-05-08): RFC-0008 §3.0 says
// `#[isr]` implies `#[atomic]`. ISR enforcement now also runs the
// atomic blocking-call check, so an ISR that locks a mutex (even
// via the friendly wrapper) surfaces a compile diagnostic. Pre-fix
// the implication was enforced for alloc/panic/dyn but not for
// blocking.
#[isr]
fn bad_isr_blocking() -> void {
    conc_lock(0);
    return;
}

fn main() -> i64 {
    bad_isr_blocking();
    return 0;
}
