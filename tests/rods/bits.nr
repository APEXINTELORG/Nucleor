// rods/bits — verify rod wrapper
import "stdlib/rods/bits.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    if bits_popcount(0xFF) != 8 { fail = fail + 1; print("FAIL popcount"); };
    if bits_leading_zeros(1) != 63 { fail = fail + 1; print("FAIL lz"); };
    if bits_trailing_zeros(8) != 3 { fail = fail + 1; print("FAIL tz"); };

    if bits_msb_index(0) != (0 - 1) { fail = fail + 1; print("FAIL msb 0"); };
    if bits_msb_index(1) != 0 { fail = fail + 1; print("FAIL msb 1"); };
    if bits_msb_index(0xFF) != 7 { fail = fail + 1; print("FAIL msb FF"); };

    if bits_lsb_index(0) != (0 - 1) { fail = fail + 1; print("FAIL lsb 0"); };
    if bits_lsb_index(8) != 3 { fail = fail + 1; print("FAIL lsb 8"); };

    if bits_is_power_of_two(0) != 0 { fail = fail + 1; print("FAIL pow2 0"); };
    if bits_is_power_of_two(1) != 1 { fail = fail + 1; print("FAIL pow2 1"); };
    if bits_is_power_of_two(8) != 1 { fail = fail + 1; print("FAIL pow2 8"); };
    if bits_is_power_of_two(7) != 0 { fail = fail + 1; print("FAIL pow2 7"); };

    if bits_next_power_of_two(0) != 1 { fail = fail + 1; print("FAIL next 0"); };
    if bits_next_power_of_two(1) != 1 { fail = fail + 1; print("FAIL next 1"); };
    if bits_next_power_of_two(7) != 8 { fail = fail + 1; print("FAIL next 7"); };
    if bits_next_power_of_two(8) != 8 { fail = fail + 1; print("FAIL next 8"); };
    if bits_next_power_of_two(9) != 16 { fail = fail + 1; print("FAIL next 9"); };

    if fail == 0 { print("OK bits"); return 0; };
    return 1;
}
