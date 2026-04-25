// T3.9 (v0.3.8) RT-005 fixture — used by the verify gate to
// assert RT-005 fires when an extern fn is called from the
// body of an RT-marked fn (#[no_alloc] / #[no_panic] /
// #[deadline]).

extern fn host_telemetry(value: i64) -> i64;

#[no_alloc]
fn rt_path(x: i64) -> i64 {
    let _ = host_telemetry(x);
    return x + 1;
}

fn main() -> i64 {
    return rt_path(0);
}
