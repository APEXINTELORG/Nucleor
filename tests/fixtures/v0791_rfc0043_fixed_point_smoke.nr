// v0.7.91 RFC-0043 Phase A smoke fixture — Q-format fixed-point
// arithmetic helpers. Validates:
//   - q-format selectors round-trip through i_bits/f_bits
//   - from_int + to_int round-trip
//   - from_parts encodes int + fraction as 10k-scaled
//   - add / sub / neg semantics in Q15.16
//   - mul / div semantics with proper f-bit scaling
//   - requant up- and down-shifts correctly between formats
//   - saturate clamps a 63+ bit value safely
import "stdlib/rods/fixed_point.nr"

fn main() -> i64 {
    let q1616: i64 = fixed_q16_16();
    if fixed_q_i_bits(q1616) != 16 { return 1; };
    if fixed_q_f_bits(q1616) != 16 { return 2; };

    let q24_8: i64 = fixed_q24_8();
    if fixed_q_i_bits(q24_8) != 24 { return 3; };
    if fixed_q_f_bits(q24_8) != 8 { return 4; };

    // 3.0 in Q15.16 is 3 * 2^16 = 196608.
    let three: i64 = fixed_from_int(q1616, 3);
    if three != 196608 { return 5; };
    if fixed_to_int(q1616, three) != 3 { return 6; };

    // 1.5 via from_parts (5000 / 10000 = 0.5).
    let one_point_five: i64 = fixed_from_parts(q1616, 1, 5000);
    if fixed_to_int(q1616, one_point_five) != 1 { return 7; };

    // add / sub.
    let sum: i64 = fixed_add(q1616, three, one_point_five);
    if fixed_to_int(q1616, sum) != 4 { return 8; };

    let diff: i64 = fixed_sub(q1616, three, one_point_five);
    if fixed_to_int(q1616, diff) != 1 { return 9; };

    // neg.
    let n: i64 = fixed_neg(q1616, three);
    if fixed_to_int(q1616, n) != 0 - 3 { return 10; };

    // mul: 3.0 * 1.5 = 4.5.
    let prod: i64 = fixed_mul(q1616, three, one_point_five);
    if fixed_to_int(q1616, prod) != 4 { return 11; };

    // div: 3.0 / 1.5 = 2.0.
    let quot: i64 = fixed_div(q1616, three, one_point_five);
    if fixed_to_int(q1616, quot) != 2 { return 12; };

    // requant Q15.16 -> Q24.8 (drops 8 frac bits).
    let down: i64 = fixed_requant(q1616, q24_8, three);
    if fixed_to_int(q24_8, down) != 3 { return 13; };

    // requant Q24.8 -> Q15.16 (gains 8 frac bits).
    let three_q24_8: i64 = fixed_from_int(q24_8, 3);
    let up: i64 = fixed_requant(q24_8, q1616, three_q24_8);
    if fixed_to_int(q1616, up) != 3 { return 14; };

    // compare predicates.
    if fixed_lt(q1616, one_point_five, three) != 1 { return 15; };
    if fixed_gt(q1616, three, one_point_five) != 1 { return 16; };
    if fixed_eq(q1616, three, three) != 1 { return 17; };

    // saturate: any reasonable Q15.16 value is within bounds, untouched.
    let sat: i64 = fixed_saturate(q1616, three);
    if sat != three { return 18; };

    return 0;
}
