// EXPECT: error[ISR-007] `#[isr(prio = -N)]` rejected
// err_isr_007_prio_negative — v0.6.32 negative fixture
// Closes gap (b) of probe finding 2026-05-02-isr-attr-validation-gaps.
// Pre-fix `#[isr(prio = -1)]` was silently accepted with undefined
// effect on the target controller (NVIC priorities are unsigned
// 0..255; PLIC unsigned 1..7).

#[isr(prio = -1)]
fn handler() {}

fn main() -> i32 { 0 }
