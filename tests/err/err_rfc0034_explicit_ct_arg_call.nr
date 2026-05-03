// EXPECT: nucleor: RFC-0034 explicit CT-arg call form not yet supported
// v0.6.63 — explicit CT-arg call halts cleanly at parse (was runtime SEGFAULT rc=139)
fn ct_inc[N: usize](x: i64) -> i64 { return x + 1; }
fn main() -> i32 {
    let r: i64 = ct_inc[42](5);
    return r as i32;
}
