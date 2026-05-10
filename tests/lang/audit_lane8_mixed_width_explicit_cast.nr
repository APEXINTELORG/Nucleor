// F-NUM-004 positive proof: mixed-width arithmetic remains available
// only when the conversion intent is explicit at the operation site.
fn main() -> i32 {
    let a: i32 = 100i32;
    let b: u32 = 200u32;
    let c: i32 = a + (b as i32);
    if c != 300i32 { return 1; };
    print("OK audit_lane8_mixed_width_explicit_cast\n");
    return 0;
}
