// Probe: long-running output exe so we can lock its file
fn main() -> i64 {
    let mut i: i64 = 0;
    while i < 100 {
        sleep_ms(100);
        i = i + 1;
    };
    return 0;
}
