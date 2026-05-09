// Lane 1 audit fix (2026-05-08) — closes C-001 / C-007.
// Pre-fix `u64 < u64` emitted `icmp slt i64` (signed compare) on the
// unsigned operands. For u64 values with the high bit set, signed
// compare gives the wrong answer (high-bit-set u64 looks negative
// in signed semantics, so it sorts BEFORE small unsigned values).
//
// This positive test verifies the post-fix behavior:
//   - u64 with bit 63 set is GREATER than 1 in unsigned semantics
//   - the signed-compare bug pre-fix would have inverted these results
fn main() -> i32 {
    let mut fail: i64 = 0;

    let h: u64 = 9223372036854775808u64;  // 2^63 (bit 63 set)
    let o: u64 = 1u64;

    // Unsigned: h > o (h is huge, o is small)
    if h < o { fail = fail + 1; print("FAIL: h < o (signed-compare bug returned)\n"); };
    if !(h > o) { fail = fail + 1; print("FAIL: !(h > o)\n"); };
    if !(h >= o) { fail = fail + 1; print("FAIL: !(h >= o)\n"); };
    if h <= o { fail = fail + 1; print("FAIL: h <= o (signed-compare bug returned)\n"); };

    // Symmetric on the small side
    if o > h { fail = fail + 1; print("FAIL: o > h\n"); };
    if !(o < h) { fail = fail + 1; print("FAIL: !(o < h)\n"); };

    // Cross-zero u64 boundary: 2^64 - 1 > 2^63
    let max_u: u64 = 18446744073709551615u64;
    if !(max_u > h) { fail = fail + 1; print("FAIL: !(max_u > h)\n"); };

    if fail == 0 { print("OK audit_lane1_u64_compare\n"); };
    fail as i32
}
