// Test: unsigned integer comparisons use correct condition codes
// Values above 2^31 must compare correctly as unsigned

fn main() -> i32 {
    // 3_000_000_000 is above i32 MAX (2_147_483_647) but valid u32
    let big: u32 = 3000000000;
    let small: u32 = 1;

    // Unsigned: 3000000000 > 1 — must be true
    let gt_result: i32 = if big > small { 1 } else { 0 };
    print_int(gt_result);  // expect: 1

    // Unsigned: 1 < 3000000000 — must be true
    let lt_result: i32 = if small < big { 1 } else { 0 };
    print_int(lt_result);  // expect: 1

    // Unsigned: 3000000000 >= 3000000000 — must be true
    let big2: u32 = 3000000000;
    let ge_result: i32 = if big >= big2 { 1 } else { 0 };
    print_int(ge_result);  // expect: 1

    // Unsigned: 1 <= 3000000000 — must be true
    let le_result: i32 = if small <= big { 1 } else { 0 };
    print_int(le_result);  // expect: 1

    // Unsigned division: 3000000000 / 2 = 1500000000 (not negative)
    let div_result: u32 = big / 2;
    let div_check: i32 = if div_result == 1500000000 { 1 } else { 0 };
    print_int(div_check);  // expect: 1

    // Unsigned modulo: 3000000000 % 7 = 3000000000 - 428571428*7 = 4
    let mod_result: u32 = big % 7;
    let mod_check: i32 = if mod_result == 4 { 1 } else { 0 };
    print_int(mod_check);  // expect: 1

    // All 6 checks passed → return 0
    // (gt + lt + ge + le + div + mod should all be 1)
    let total: i32 = gt_result + lt_result + ge_result + le_result + div_check + mod_check;
    if total == 6 { 0 } else { 1 }
}
