// T-4 strict inference positive lock for format/string conversion helpers.
// These helpers have concrete scalar/string return types and must not fall
// through the empty-type sentinel under NUC_STRICT_INFERENCE=1.

fn main() -> i64 {
    let eq: i64 = str_eq("nucleor", "nucleor");
    let concat: str = str_concat("nu", "cleor");
    let lower: str = str_to_lower("ABC");
    let upper: str = str_to_upper("abc");
    let replaced: str = str_replace("a-b", "-", "+");
    let repeated: str = str_repeat("na", 2);
    let reversed: str = str_reverse("roelcun");
    let left: str = str_pad_left("7", 3, 48);
    let right: str = str_pad_right("7", 3, 48);
    let centered: str = str_center("x", 3, 32);

    let starts: i64 = str_starts_with("nucleor", "nuc");
    let ends: i64 = str_ends_with("nucleor", "or");
    let idx: i64 = str_index_of("nucleor", "leo");
    let contains: i64 = str_contains("nucleor", "cle");
    let empty: i64 = str_is_empty("");
    let count: i64 = str_count("aaaa", "aa");

    let p1: i64 = str_to_i64("123");
    let p2: i64 = str_to_int("124");
    let p3: i64 = str_to_int_strict("125");
    let p4: i64 = str_to_bool("true");
    let p5: i64 = str_to_i64_radix("ff", 16);
    let p6: i64 = parse_hex("ff");
    let p7: i64 = parse_bin("1010");

    let s1: str = int_to_str(42);
    let s2: str = str_from_int(43);
    let s3: str = bool_to_str(1);
    let s4: str = int_to_hex(255);
    let s5: str = int_to_bin(5);
    let s6: str = int_to_oct(8);
    let s7: str = int_to_str_force_sign(9);
    let s8: str = int_to_hex_upper(255);

    let f1: str = format_i64("n={}", 5);
    let f2: str = format_str("s={}", "ok");
    let f3: str = format_hex("x={}", 255);
    let f4: str = format_bool("b={}", 1);
    let f5: str = format2_ii("{}+{}", 2, 3);
    let f6: str = format2_si("{}={}", "n", 7);
    let f7: str = format2_ss("{}{}", "a", "b");
    let f8: str = format2_is("{}{}", 1, "b");
    let f9: str = format3_iii("{}/{}/{}", 1, 2, 3);
    let f10: str = format3_sss("{}{}{}", "a", "b", "c");

    if eq != 1 { return 1; };
    if str_eq(concat, "nucleor") != 1 { return 2; };
    if str_eq(lower, "abc") != 1 { return 4; };
    if str_eq(upper, "ABC") != 1 { return 8; };
    if str_eq(replaced, "a+b") != 1 { return 16; };
    if str_eq(repeated, "nana") != 1 { return 32; };
    if str_eq(reversed, "nucleor") != 1 { return 64; };
    if str_eq(left, "007") != 1 { return 128; };
    if str_eq(right, "700") != 1 { return 256; };
    if str_eq(centered, " x ") != 1 { return 512; };

    if starts != 1 || ends != 1 || idx != 3 || contains != 1 || empty != 1 || count != 2 { return 1024; };
    if p1 != 123 || p2 != 124 || p3 != 125 || p4 != 1 || p5 != 255 || p6 != 255 || p7 != 10 { return 2048; };
    if str_eq(s1, "42") != 1 || str_eq(s2, "43") != 1 || str_eq(s3, "true") != 1 { return 4096; };
    if str_len(s4) <= 0 || str_len(s5) <= 0 || str_len(s6) <= 0 || str_len(s7) <= 0 || str_len(s8) <= 0 { return 8192; };
    if str_eq(f1, "n=5") != 1 || str_eq(f2, "s=ok") != 1 || str_eq(f3, "x=0xff") != 1 || str_eq(f4, "b=true") != 1 { return 16384; };
    if str_eq(f5, "2+3") != 1 || str_eq(f6, "n=7") != 1 || str_eq(f7, "ab") != 1 || str_eq(f8, "1b") != 1 { return 32768; };
    if str_eq(f9, "1/2/3") != 1 || str_eq(f10, "abc") != 1 { return 65536; };
    return 0;
}
