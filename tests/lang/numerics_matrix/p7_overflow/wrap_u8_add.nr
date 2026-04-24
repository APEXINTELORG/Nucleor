// p7_overflow/wrap_u8_add.nr — Phase 7: u8 wrap (default in release)

fn main() -> i32 {
    let a: u8 = 250;
    let b: u8 = 10;
    let c: u8 = a + b;     // wraps to 4 (260 mod 256)
    if c != 4 {
        print("FAIL: u8 wrap-mode add\n");
        return 1;
    };
    print("OK wrap_u8_add\n");
    return 0;
}
