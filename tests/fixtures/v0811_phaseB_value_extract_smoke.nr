// v0.8.11 Phase B step-2 smoke fixture — numeric value
// extraction from @energy / @thermal / @within attributes.
// Build emits:
//   audit: @energy budgets in build: 2
//   audit:   energy values: 2mJ; 500uJ
//   audit: @thermal budgets in build: 1
//   audit:   thermal values: -40C
//   audit: @within timing constraints in build: 1
//   audit:   timing values: 200ns
// rc = 4.

@energy(max=2mJ)
fn pid_step() -> i64 { return 1; }

@energy(max=500uJ)
fn filter_apply() -> i64 { return 1; }

@thermal(min_temp=-40C, max_temp=85C)
fn auto_loop() -> i64 { return 1; }

@within(200ns)
fn timed() -> i64 { return 1; }

fn main() -> i64 {
    return pid_step() + filter_apply() + auto_loop() + timed();
}
