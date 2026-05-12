// Regression gate / F-CONC-003: #[deadline] must poll inside long-running
// loops, not only compare elapsed time after the function returns.

#[deadline = 100us]
#[no_alloc]
fn deadline_loop_poll() -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 0;
    while i < 10000000 {
        acc = acc + i;
        i = i + 1;
    };
    return acc;
}

fn main() -> i64 {
    let r: i64 = deadline_loop_poll();
    println!("deadline loop returned {}", r);
    return 0;
}
