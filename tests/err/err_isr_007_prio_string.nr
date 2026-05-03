// EXPECT: error[ISR-007] `#[isr(prio = "...")]` rejected
// err_isr_007_prio_string — v0.6.32 negative fixture
// Closes gap (c) of probe finding 2026-05-02-isr-attr-validation-gaps.
// Pre-fix `#[isr(prio = "high")]` was silently accepted; the string
// was ignored and the priority defaulted with no diag.

#[isr(prio = "high")]
fn handler() {}

fn main() -> i32 { 0 }
