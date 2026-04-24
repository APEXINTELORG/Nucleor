// p12_rods/rod_call_with_narrow.nr — Phase 12: confirm existing
// i64-FFI rods accept narrow-typed values without changes.
// The Phase 6 narrow→i64 widening rule means u8 / u16 / u32 args
// flow into the rod's i64 signature; the Phase 1 narrow_via_as
// hook truncates the i64 result back to u8 on the let-binding.
//
// This is the audit principle in action: 221 rods stay
// i64-FFI by default and narrow-type users still get correct
// width semantics end-to-end.
import "stdlib/rods/bitwise.nr"

fn main() -> i32 {
    let a: u8 = 0xF0;
    let b: u8 = 0x0F;
    let c: u8 = bit_and(a, b);     // expect 0
    let d: u8 = bit_or(a, b);      // expect 0xFF (= 255)
    let e: u8 = bit_xor(a, b);     // expect 0xFF
    if c != 0   { print("FAIL: bit_and narrow round-trip\n"); return 1; };
    if d != 255 { print("FAIL: bit_or narrow round-trip\n"); return 1; };
    if e != 255 { print("FAIL: bit_xor narrow round-trip\n"); return 1; };
    print("OK rod_call_with_narrow\n");
    return 0;
}
