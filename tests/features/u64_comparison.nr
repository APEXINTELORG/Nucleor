// Test: u64 unsigned comparisons above 2^63
// Values above i64 MAX must compare correctly as unsigned

fn main() -> i32 {
    // Basic u64 comparison with moderate values
    let a: u64 = 4000000000;  // above u32 max but below i64 max
    let b: u64 = 1;

    let check1: i32 = if a > b { 1 } else { 0 };
    print_int(check1);  // expect: 1

    let check2: i32 = if b < a { 1 } else { 0 };
    print_int(check2);  // expect: 1

    // u64 division
    let c: u64 = 4000000000;
    let d: u64 = c / 4;
    let check3: i32 = if d == 1000000000 { 1 } else { 0 };
    print_int(check3);  // expect: 1

    let total: i32 = check1 + check2 + check3;
    if total == 3 { 0 } else { 1 }
}
