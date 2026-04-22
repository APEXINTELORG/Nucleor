// print_widths.nr — RFC-0015 phase 5: per-width print helpers

fn main() -> i32 {
    // Smoke test: each helper must build, link, and run without crash.
    print_i8(127);
    print_i8(0 - 128);
    print_i16(32767);
    print_i32(2147483647);
    print_u8(255);
    print_u16(65535);
    print_u32(4294967295);
    print_u64(18446744073709551615);   // u64::MAX
    print_hex(255);
    print_bin(255);
    print_hex(0);
    print_bin(0);
    print("OK print_widths");
    return 0;
}
