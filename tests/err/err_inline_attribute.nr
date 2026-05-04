// EXPECT: nucleor: inline attribute not yet supported
// v0.7.18 - inline attributes halt cleanly instead of being silently dropped.
#[inline(always)]
fn hot_add(x: i64) -> i64 {
    return x + 1;
}

fn main() -> i32 {
    return hot_add(1) as i32;
}
