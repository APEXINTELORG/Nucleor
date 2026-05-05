// R09-D1 / RFC-0043 fixed<I,F> semantic type tracking.
//
// Valid same-Q-format fixed values should keep compiling while the
// compiler preserves the full fixed<I,F> type for compatibility checks.
// Storage still lowers through the current i64 ABI.
//
// Expected: rc=0.

fn add_q88(a: fixed<8, 8>, b: fixed<8, 8>) -> fixed<8, 8> {
    let c: fixed<8, 8> = a + b;
    return c;
}

fn main() -> i64 {
    let a: fixed<8, 8> = 10;
    let b: fixed<8, 8> = 20;
    let c: fixed<8, 8> = add_q88(a, b);
    if c != 30 { return 1; };
    return 0;
}
