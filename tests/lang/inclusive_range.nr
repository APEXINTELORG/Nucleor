// inclusive_range.nr — RFC-0023 partial: `..=` inclusive range in for loops

fn main() -> i32 {
    let mut fail: i64 = 0;

    // Exclusive range 0..5 → 0,1,2,3,4 → 5 iterations
    let mut sum_excl: i64 = 0;
    let mut count_excl: i64 = 0;
    for i in 0..5 {
        sum_excl = sum_excl + i;
        count_excl = count_excl + 1;
    };
    if sum_excl != 10 { fail = fail + 1; print("FAIL exclusive sum\n"); };
    if count_excl != 5 { fail = fail + 1; print("FAIL exclusive count\n"); };

    // Inclusive range 0..=5 → 0,1,2,3,4,5 → 6 iterations
    let mut sum_incl: i64 = 0;
    let mut count_incl: i64 = 0;
    for i in 0..=5 {
        sum_incl = sum_incl + i;
        count_incl = count_incl + 1;
    };
    if sum_incl != 15 { fail = fail + 1; print("FAIL inclusive sum\n"); };
    if count_incl != 6 { fail = fail + 1; print("FAIL inclusive count\n"); };

    // Inclusive 1..=10
    let mut prod: i64 = 1;
    for i in 1..=10 {
        prod = prod * i;
    };
    if prod != 3628800 { fail = fail + 1; print("FAIL 10!\n"); };

    if fail == 0 { print("OK inclusive_range\n"); return 0; };
    return 1;
}
