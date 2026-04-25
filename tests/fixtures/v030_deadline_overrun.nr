// v0.3.0 (T3.1) overrun fixture — used by the verify gate's
// dedicated overrun step (build + run + expect exit 1 +
// expect "RT-004" in stderr). NOT used by the test framework
// or the negative-fixture sweep.

#[deadline = 1]
fn overrun_fn() -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 0;
    while i < 5000000 {
        acc = acc + i;
        i = i + 1;
    };
    return acc;
}

fn main() -> i64 {
    let r: i64 = overrun_fn();
    println!("got {}", r);
    return 0;
}
