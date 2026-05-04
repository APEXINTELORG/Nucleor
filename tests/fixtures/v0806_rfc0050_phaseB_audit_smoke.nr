// v0.8.6 RFC-0050 Phase B step-1 smoke fixture — @energy /
// @thermal audit count. Tags 2 fns with energy budgets, 1 with
// thermal range. Build emits two one-line audit summaries:
//   audit: @energy budgets in build: 2
//   audit: @thermal budgets in build: 1
// rc=0 confirms the attributes parse cleanly via the lex-time
// skip.

@energy(max=2mJ)
fn pid_step(setpoint: i64, measured: i64) -> i64 {
    let err: i64 = setpoint - measured;
    return err * 2;
}

@energy(max=500uJ)
fn filter_apply(x: i64) -> i64 {
    return x + 1;
}

@thermal(min_temp=-40C, max_temp=85C)
fn automotive_loop(x: i64) -> i64 {
    return x;
}

fn main() -> i64 {
    let a: i64 = pid_step(100, 80);  // 40
    let b: i64 = filter_apply(7);    // 8
    let c: i64 = automotive_loop(5); // 5
    return a + b + c;                 // 53
}
