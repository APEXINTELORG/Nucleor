// v0.8.187 stdlib/rods/fixed_point.nr first test coverage.
//
// RFC-0043 Phase A — Q-format fixed-point arithmetic helpers.
// The runtime API adopters use today; the IR-type drift
// restoration (Phase B) is audit-shipped at v0.8.143/v0.8.181.
// Pre-v0.8.187: zero coverage on the rod itself.
//
// Locks five textbook Q-format invariants on Q16.16:
//
//   1. **Q-format encode/decode**: q_i_bits and q_f_bits round-trip.
//   2. **Integer round-trip**: from_int(3) → to_int → 3.
//   3. **from_parts**: from_parts(1, 5000) ≈ 1.5 in Q16.16
//      (98304 scale = 1.5 * 65536).
//   4. **Add**: from_int(2) + from_int(3) → to_int → 5.
//   5. **Mul**: from_parts(1,5000) × from_parts(2,0) →
//      to_int → 3 (1.5 × 2 = 3).
//
// Expected: rc=0.

import "stdlib/rods/fixed_point.nr"

fn check_q_encode() -> i64 {
    let q: i64 = fixed_q16_16();
    if fixed_q_i_bits(q) != 16 { return 1; };
    if fixed_q_f_bits(q) != 16 { return 2; };
    return 0;
}

fn check_int_round_trip() -> i64 {
    let q: i64 = fixed_q16_16();
    let a: i64 = fixed_from_int(q, 3);
    if fixed_to_int(q, a) != 3 { return 4; };
    return 0;
}

fn check_from_parts_one_and_a_half() -> i64 {
    let q: i64 = fixed_q16_16();
    // 1.5 in Q16.16 = 1.5 * 65536 = 98304
    let a: i64 = fixed_from_parts(q, 1, 5000);
    if a != 98304 { return 8; };
    return 0;
}

fn check_add() -> i64 {
    let q: i64 = fixed_q16_16();
    let a: i64 = fixed_from_int(q, 2);
    let b: i64 = fixed_from_int(q, 3);
    let c: i64 = fixed_add(q, a, b);
    if fixed_to_int(q, c) != 5 { return 16; };
    return 0;
}

fn check_mul() -> i64 {
    let q: i64 = fixed_q16_16();
    let a: i64 = fixed_from_parts(q, 1, 5000); // 1.5
    let b: i64 = fixed_from_int(q, 2);          // 2.0
    let c: i64 = fixed_mul(q, a, b);
    if fixed_to_int(q, c) != 3 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_q_encode();
    fails = fails + check_int_round_trip();
    fails = fails + check_from_parts_one_and_a_half();
    fails = fails + check_add();
    fails = fails + check_mul();
    return fails;
}
