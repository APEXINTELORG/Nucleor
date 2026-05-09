// Lane 1 audit fix (2026-05-08) — closes C-003.
// Pre-fix `u64 / u64` and `u64 % u64` routed through the SIGNED
// `__nucleor_panic_div_i64` / `_rem_i64` helpers, so a u64 with the
// high bit set was reinterpreted as a negative i64 inside the helper
// and produced wrong quotients/remainders.
//
// Differential reference:
//   18446744073709551614 / 2  = 9223372036854775807   (2^64 - 2 over 2 = 2^63 - 1)
//   pre-fix returned -1 (because (i64)18446744073709551614 = -2; -2 / 2 = -1).
fn main() -> i32 {
    let mut fail: i64 = 0;

    let n: u64 = 18446744073709551614u64;  // 2^64 - 2
    let d: u64 = 2u64;
    let q: u64 = n / d;
    let q_i: i64 = q as i64;
    let expected: i64 = 9223372036854775807;  // 2^63 - 1
    if q_i != expected {
        fail = fail + 1;
        print("FAIL: u64 div expected 9223372036854775807, got ");
        print_int(q_i);
        print("\n");
    };

    // Modulo case: max_u % 7 has a non-trivial answer in unsigned semantics.
    // 18446744073709551615 % 7 = 1 (2^64 - 1 = 7 * 2635249153387078802 + 1).
    // Pre-fix the signed div-rem helper interpreted max_u as -1 i64, and
    // `(-1) % 7` in C is implementation-defined — typically -1, which is
    // also wrong by a different mechanism.
    let max_u: u64 = 18446744073709551615u64;
    let seven: u64 = 7u64;
    let r: u64 = max_u % seven;
    let r_i: i64 = r as i64;
    if r_i != 1 {
        fail = fail + 1;
        print("FAIL: u64 mod expected 1, got ");
        print_int(r_i);
        print("\n");
    };

    if fail == 0 { print("OK audit_lane1_u64_divmod\n"); };
    fail as i32
}
