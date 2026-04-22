// base_conv — RFC-0017 stdlib enrichment.
//
//   int_to_hex(v)              -> str
//   int_to_bin(v)              -> str
//   int_to_oct(v)              -> str
//   str_to_i64_radix(s, r)     -> i64
//   parse_hex(s)               -> i64
//   parse_bin(s)               -> i64

fn main() -> i64 {
    let mut fail: i64 = 0;

    // int_to_hex
    if !str_eq(int_to_hex(255), "ff")     { fail = fail + 1; print("FAIL int_to_hex 255"); };
    if !str_eq(int_to_hex(0), "0")        { fail = fail + 1; print("FAIL int_to_hex 0"); };
    if !str_eq(int_to_hex(4096), "1000")  { fail = fail + 1; print("FAIL int_to_hex 4096"); };

    // int_to_bin
    if !str_eq(int_to_bin(0), "0")        { fail = fail + 1; print("FAIL int_to_bin 0"); };
    if !str_eq(int_to_bin(5), "101")      { fail = fail + 1; print("FAIL int_to_bin 5"); };
    if !str_eq(int_to_bin(8), "1000")     { fail = fail + 1; print("FAIL int_to_bin 8"); };

    // int_to_oct
    if !str_eq(int_to_oct(8), "10")       { fail = fail + 1; print("FAIL int_to_oct 8"); };
    if !str_eq(int_to_oct(64), "100")     { fail = fail + 1; print("FAIL int_to_oct 64"); };

    // parse_hex (case insensitive, prefix tolerated)
    if parse_hex("ff") != 255             { fail = fail + 1; print("FAIL parse_hex ff"); };
    if parse_hex("0xff") != 255           { fail = fail + 1; print("FAIL parse_hex 0xff"); };
    if parse_hex("FF") != 255             { fail = fail + 1; print("FAIL parse_hex FF"); };
    if parse_hex("0XCAFE") != 51966       { fail = fail + 1; print("FAIL parse_hex CAFE"); };
    if parse_hex("cab") != 3243           { fail = fail + 1; print("FAIL parse_hex cab"); };
    if parse_hex("garbage") != 0          { fail = fail + 1; print("FAIL parse_hex garbage"); };

    // parse_bin
    if parse_bin("101") != 5              { fail = fail + 1; print("FAIL parse_bin 101"); };
    if parse_bin("0b1000") != 8           { fail = fail + 1; print("FAIL parse_bin 0b1000"); };
    if parse_bin("11111111") != 255       { fail = fail + 1; print("FAIL parse_bin 255"); };

    // str_to_i64_radix: arbitrary radix
    if str_to_i64_radix("z", 36) != 35    { fail = fail + 1; print("FAIL radix 36"); };
    if str_to_i64_radix("777", 8) != 511  { fail = fail + 1; print("FAIL radix 8"); };
    if str_to_i64_radix("-ff", 16) != -255 { fail = fail + 1; print("FAIL radix neg hex"); };

    // Round trip: 0xdeadbeef = 3735928559
    let big: i64 = 3735928559;
    if parse_hex(int_to_hex(big)) != big {
        fail = fail + 1; print("FAIL hex round-trip");
    };

    if fail == 0 { print("OK base_conv"); return 0; };
    return 1;
}
