// Lane 3 (C-008): differential codegen reference.
//
// Each line of stdout is a label + value computed by Nucleor.
// A sister C reference is in tests/diff/lane3_diff_int_widths.c.
// The verify step compiles+runs both and bit-compares stdout.
// If Nucleor's i64-everywhere class flips a u8 add into i64 sign
// extension, this file's output diverges from the C output and
// the diff step fails.

fn print_i64_kv(k: str, v: i64) {
    // Build "key=value" as one string so __nucleor_print_str's
    // implicit trailing newline produces one line per kv pair —
    // matches the C reference's single printf("%s=%lld\n", ...).
    print(str_concat(k, str_concat("=", str_from_int(v))));
}

fn main() -> i64 {
    // u8 wrap: 200 + 100 == 44 (mod 256).
    let u8a: u8 = 200;
    let u8b: u8 = 100;
    let u8s: u8 = u8a + u8b;
    print_i64_kv("u8_wrap", u8s as i64);

    // u32 wrap: 4294967290 + 10 == 4 (mod 2^32).
    let u32a: u32 = 4294967290;
    let u32b: u32 = 10;
    let u32s: u32 = u32a + u32b;
    print_i64_kv("u32_wrap", u32s as i64);

    // i32 sign-extension on widening.
    let i32a: i32 = -1;
    let widened: i64 = i32a as i64;
    print_i64_kv("i32_sx", widened);

    // u32 zero-extension on widening — must be 0xFFFFFFFF as i64,
    // not -1.
    let u32c: u32 = 4294967295;
    let widened_u: i64 = u32c as i64;
    print_i64_kv("u32_zx", widened_u);

    // i8 truncation on narrowing.
    let i64a: i64 = 257;
    let truncated: i8 = i64a as i8;
    print_i64_kv("i8_trunc", truncated as i64);

    // Signed division truncates toward zero, not floor.
    print_i64_kv("sdiv_neg", -7 / 2);
    print_i64_kv("smod_neg", -7 % 2);

    return 0;
}
