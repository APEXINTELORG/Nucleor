// hex_oct_bin_literals.nr — RFC-0015 §3.6: hex/octal/binary integer literals

fn main() -> i32 {
    let mut fail: i64 = 0;

    // Hex
    if 0xAB != 171 { fail = fail + 1; print("FAIL: 0xAB\n"); };
    if 0xFF != 255 { fail = fail + 1; print("FAIL: 0xFF\n"); };
    if 0xDEAD_BEEF != 3735928559 { fail = fail + 1; print("FAIL: 0xDEAD_BEEF\n"); };
    if 0xFFFFFFFF != 4294967295 { fail = fail + 1; print("FAIL: 0xFFFFFFFF\n"); };
    if 0X10 != 16 { fail = fail + 1; print("FAIL: 0X10 uppercase\n"); };

    // Octal
    if 0o777 != 511 { fail = fail + 1; print("FAIL: 0o777\n"); };
    if 0o10 != 8 { fail = fail + 1; print("FAIL: 0o10\n"); };

    // Binary
    if 0b1010 != 10 { fail = fail + 1; print("FAIL: 0b1010\n"); };
    if 0b1111_1111 != 255 { fail = fail + 1; print("FAIL: 0b1111_1111\n"); };
    if 0B1 != 1 { fail = fail + 1; print("FAIL: 0B1 uppercase\n"); };

    // Mixed in arithmetic
    if 0xFF + 1 != 256 { fail = fail + 1; print("FAIL: hex arithmetic\n"); };
    if 0b10 * 0b11 != 6 { fail = fail + 1; print("FAIL: binary arithmetic\n"); };

    // Suffixes on radix literals
    if 0xFFu8 != 255 { fail = fail + 1; print("FAIL: 0xFFu8\n"); };

    if fail == 0 { print("OK hex_oct_bin_literals\n"); return 0; };
    return 1;
}
