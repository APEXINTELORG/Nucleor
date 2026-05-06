// RT-G5 contract fixture: #[deadline] currently has runtime checks
// plus a heuristic RT-004 estimator, not certified static WCET.
// Expected compile behavior: RT-004 warning mentions "heuristic
// deadline estimate" and "NOT certified WCET".

#[deadline = 1us]
fn deadline_loop() -> i64 {
    let mut x: i64 = 0;
    loop {
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        if x > 16 { break; };
    };
    return x;
}

fn main() -> i64 {
    return 0;
}
