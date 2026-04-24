// p7_overflow/wrapping_add_u8.nr — Phase 7: explicit wrapping_add intrinsic

fn main() -> i32 {
    let a: u8 = 250;
    let b: u8 = 10;
    let c: u8 = wrapping_add::<u8>(a, b);
    if c != 4 {
        print("FAIL: wrapping_add::<u8>\n");
        return 1;
    };
    print("OK wrapping_add_u8\n");
    return 0;
}
