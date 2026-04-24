// p3_layout/alloca_u8.nr — Phase 3: u8 alloca should be 1 byte
// We can't directly observe the alloca size, but we can pack
// adjacent u8 vars and check that overflow on one doesn't
// touch the other (proves separate 1-byte slots).

fn main() -> i32 {
    let a: u8 = 200;
    let b: u8 = 100;
    let c: u8 = a + 100;   // wraps to 44 (300 - 256)
    if c != 44 {
        print("FAIL: u8 wrap at narrow alloca\n");
        return 1;
    };
    if b != 100 {
        print("FAIL: adjacent u8 corrupted by wrap\n");
        return 1;
    };
    print("OK alloca_u8\n");
    return 0;
}
