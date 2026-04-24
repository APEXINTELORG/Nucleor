// p7_overflow/checked_add_u8.nr — Phase 7: checked returns flag
// via the side-channel checked_overflow_flag() (matches the i64
// checked_* convention; tuple/Option returns land with T1.2).

fn main() -> i32 {
    let a: u8 = 250;
    let b: u8 = 10;
    let _ = checked_add_u8(a, b);
    let of: i64 = checked_overflow_flag();
    if of != 1 {
        print("FAIL: checked_add_u8 overflow flag\n");
        return 1;
    };
    print("OK checked_add_u8\n");
    return 0;
}
