// p7_overflow/saturating_add_u8.nr — Phase 7: saturating clamp.

fn main() -> i32 {
    let a: u8 = 250;
    let b: u8 = 10;
    let c: u8 = saturating_add_u8(a, b);
    if c != 255 {
        print("FAIL: saturating_add_u8 should clamp to 255\n");
        return 1;
    };
    print("OK saturating_add_u8\n");
    return 0;
}
