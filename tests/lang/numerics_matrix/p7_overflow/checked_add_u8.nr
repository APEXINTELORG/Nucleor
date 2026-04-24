// p7_overflow/checked_add_u8.nr — Phase 7: checked returns flag

fn main() -> i32 {
    let a: u8 = 250;
    let b: u8 = 10;
    let (c, of): (u8, bool) = checked_add::<u8>(a, b);
    if !of {
        print("FAIL: checked_add::<u8> overflow flag\n");
        return 1;
    };
    print("OK checked_add_u8\n");
    return 0;
}
