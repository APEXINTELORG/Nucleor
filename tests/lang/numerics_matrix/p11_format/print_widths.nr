// p11_format/print_widths.nr — Phase 11: width-correct print_<T>
// helpers for every integer width. Verifies the helpers are wired
// end-to-end; specific output formatting (with/without newline,
// leading zeros, etc.) is covered by the fmt.nr rod.

fn main() -> i32 {
    // These just verify the calls compile, link, and return 0.
    // Visual output is informational only; the test passes when
    // each call returns a valid i64 (which all print_* do: 0).
    let mut fails: i64 = 0;

    let r1: i64 = print_i8(0 - 42);     if r1 != 0 { fails = fails + 1; };
    let r2: i64 = print_i16(0 - 300);   if r2 != 0 { fails = fails + 1; };
    let r3: i64 = print_i32(0 - 1);     if r3 != 0 { fails = fails + 1; };
    let r4: i64 = print_u8(200);        if r4 != 0 { fails = fails + 1; };
    let r5: i64 = print_u16(60000);     if r5 != 0 { fails = fails + 1; };
    let r6: i64 = print_u32(3000000000); if r6 != 0 { fails = fails + 1; };

    if fails != 0 {
        print("FAIL: print_<T> width helper\n");
        return 1;
    };
    print("OK print_widths\n");
    return 0;
}
