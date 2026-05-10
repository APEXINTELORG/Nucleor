// Direct suffixed-literal coverage for C-001/C-002/C-003.
// The original lane-1 fixtures route through u64-typed locals. This pins
// the expression form adopters actually write in constants and guards.
fn main() -> i32 {
    let mut fail: i64 = 0;

    if 9223372036854775808u64 < 1u64 {
        fail = fail + 1;
        print("FAIL: direct u64 literal compare lowered signed\n");
    };
    if !(18446744073709551615u64 > 9223372036854775808u64) {
        fail = fail + 1;
        print("FAIL: direct u64 literal compare max > high failed\n");
    };

    let shifted: i64 = (9223372036854775808u64 >> 1u64) as i64;
    if shifted != 4611686018427387904 {
        fail = fail + 1;
        print("FAIL: direct u64 literal shift expected 4611686018427387904, got ");
        print_int(shifted);
        print("\n");
    };

    let q: i64 = (18446744073709551614u64 / 2u64) as i64;
    if q != 9223372036854775807 {
        fail = fail + 1;
        print("FAIL: direct u64 literal div expected 9223372036854775807, got ");
        print_int(q);
        print("\n");
    };

    if fail == 0 { print("OK audit_lane1_u64_direct_literals\n"); };
    fail as i32
}
