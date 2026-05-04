// v0.8.13 Phase B step-3 smoke fixture — multi-key range
// capture for @thermal. The single-key fallback from v0.8.11
// only captured the FIRST key=val pair; v0.8.13 captures all
// of them. Build emits:
//   audit: @thermal budgets in build: 2
//   audit:   thermal values: min_temp=-40C; max_temp=85C; max_temp=70C
// (3 pieces from 2 fns: one range + one max-only)
// rc = 2.

@thermal(min_temp=-40C, max_temp=85C)
fn auto_loop() -> i64 { return 1; }

@thermal(max_temp=70C)
fn warm_path() -> i64 { return 1; }

fn main() -> i64 {
    return auto_loop() + warm_path();
}
