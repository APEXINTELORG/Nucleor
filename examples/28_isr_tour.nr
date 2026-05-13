//! `#[isr]` tour.
//!
//! Single runnable program exercising the ISR attribute surface.
//! Compile with `nuc build examples/28_isr_tour.nr` and run on a host
//! target; prints 1 OK line and exits 0. The ISR fns survive parse +
//! type-check (asserting their `fn() -> void` shape and inheriting
//! `#[no_alloc]` + `#[no_panic]`), then DCE strips them on host builds
//! since no caller exists.
//!
//! On host targets, the compiler accepts the attribute and emits a
//! conservative IR marker. Embedded targets can lower the same shape
//! to platform interrupt calling conventions.

#[isr]
fn systick_handler() {
    // Empty body - minimal ISR stub. Real systick handlers tick a
    // counter or schedule deferred work via an SPSC queue; both
    // patterns survive #[no_alloc] + #[no_panic] inheritance.
}

#[isr(prio = 1)]
fn uart_rx_handler() {
    // Stack-only locals are fine inside an ISR. No Vec allocation,
    // no panic call sites - both would be rejected by the inherited
    // RT-001 / RT-002 check.
    let scratch: i64 = 0;
    let next: i64 = scratch + 1;
}

#[isr(prio = 2)]
fn timer0_handler() {
    // Multiple #[isr] fns coexist; each gets its own IR marker
    // and can be installed at a different vector slot at link time.
}

fn main() -> i32 {
    print("OK 28_isr_tour: 3 ISR handlers parsed + type-checked");
    return 0;
}
