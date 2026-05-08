// Lane 6 / F-NUM-003 (audit 2026-05-08): valid shift counts (0..63)
// continue to behave per spec after bounds-check hardening. The
// negative path (out-of-range panic) is exercised by a standalone
// runtime-fail probe; this test pins the positive surface.
import "stdlib/rods/bitwise.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;
    // Boundary: shift by 0 is identity
    if bit_shift_left(7, 0) != 7 { fail = fail + 1; print("FAIL <<0"); };
    if bit_shift_right(7, 0) != 7 { fail = fail + 1; print("FAIL >>0"); };
    // Mid-range
    if bit_shift_left(1, 4) != 16 { fail = fail + 1; print("FAIL 1<<4"); };
    if bit_shift_right(16, 4) != 1 { fail = fail + 1; print("FAIL 16>>4"); };
    // Boundary: shift by 63
    let lo: i64 = bit_shift_left(1, 63);
    if lo == 0 { fail = fail + 1; print("FAIL 1<<63 zero"); };
    // Bit set/clear/test in valid range
    if bit_set(0, 5) != 32 { fail = fail + 1; print("FAIL set 5"); };
    if bit_clear(0 - 1, 0) == 0 - 1 { fail = fail + 1; print("FAIL clear 0"); };
    if bit_test(8, 3) != 1 { fail = fail + 1; print("FAIL test 3 of 8"); };
    if fail == 0 { print("OK lane6_bitwise_legit"); };
    return fail;
}
