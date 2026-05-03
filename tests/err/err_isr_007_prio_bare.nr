// EXPECT: error[ISR-007] `#[isr(prio)]` is missing a value
// err_isr_007_prio_bare — v0.6.32 negative fixture
// Closes gap (d) of probe finding 2026-05-02-isr-attr-validation-gaps.
// Pre-fix bare `#[isr(prio)]` (no `= N`) was silently accepted —
// the priority defaulted with no diag, and adopters had no signal
// that the attribute was malformed.

#[isr(prio)]
fn handler() {}

fn main() -> i32 { 0 }
