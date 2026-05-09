// Lane 1 audit fix (2026-05-08) — closes C-002.
// Pre-fix `u64 >> n` emitted `ashr` (arithmetic / sign-extending right
// shift) regardless of operand signedness. For u64 with bit 63 set,
// ashr fills the upper bits with 1 — wrong for unsigned semantics.
// Post-fix routes u64 right shift to `lshr` (logical / zero-filling).
//
// Differential reference (computed by hand):
//   0x8000_0000_0000_0000 lshr 1 = 0x4000_0000_0000_0000 = 4611686018427387904
// pre-fix returned 0xC000_0000_0000_0000 (= -4611686018427387904 as i64),
// the ashr result.
fn main() -> i32 {
    let mut fail: i64 = 0;

    let h: u64 = 9223372036854775808u64;  // bit 63 set
    let r: u64 = h >> 1u64;

    // Reinterpret to i64 for printing.
    let r_i: i64 = r as i64;
    let expected: i64 = 4611686018427387904;
    if r_i != expected {
        fail = fail + 1;
        print("FAIL: u64 >> 1 expected 4611686018427387904, got ");
        print_int(r_i);
        print("\n");
    };

    // Multi-bit shift: max_u64 >> 4 = 0x0FFF...
    let max_u: u64 = 18446744073709551615u64;
    let r2: u64 = max_u >> 4u64;
    let r2_i: i64 = r2 as i64;
    let expected2: i64 = 1152921504606846975;  // 2^60 - 1
    if r2_i != expected2 {
        fail = fail + 1;
        print("FAIL: max_u >> 4 expected 1152921504606846975, got ");
        print_int(r2_i);
        print("\n");
    };

    if fail == 0 { print("OK audit_lane1_u64_shift\n"); };
    fail as i32
}
