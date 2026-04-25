// EXPECT: error[RT-007]
// T3.13 (v0.3.21) — #[deny_fn(RT-007)] on a fn that fires
// RT-007 promotes the warning to error for THAT fn only. The
// negative test fixture sweep auto-runs this and expects the
// build to fail with a diagnostic line, which is exactly what
// promote-to-error does.

#[deadline = 1000]
#[deny_fn(RT-007)]
fn critical_step(x: i64) -> i64 {
    return x + 1;
}

fn main() -> i64 {
    return critical_step(0);
}
