// EXPECT: nucleor: higher-ranked trait bounds `for<'a>` not yet supported
// v0.7.18 - HRTB where-bounds halt cleanly instead of degrading into TYP-019 on Fn/i64.
fn apply<F>(x: i64) -> i64 where F: for<'a> Fn(&'a i64) -> i64 {
    return x;
}

fn main() -> i32 {
    return apply(7) as i32;
}
