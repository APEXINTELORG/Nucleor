// arith.nr — integer arithmetic
fn main() -> i64 {
    let mut fail: i64 = 0;
    if 2 + 3 != 5 { print("FAIL arith: add"); fail = fail + 1; };
    if 10 - 4 != 6 { print("FAIL arith: sub"); fail = fail + 1; };
    if 6 * 7 != 42 { print("FAIL arith: mul"); fail = fail + 1; };
    if 100 / 5 != 20 { print("FAIL arith: div"); fail = fail + 1; };
    if 17 - (17 / 5) * 5 != 2 { print("FAIL arith: mod-via-div"); fail = fail + 1; };
    if 0 - 5 != -5 { print("FAIL arith: negate"); fail = fail + 1; };
    if (3 + 4) * 2 != 14 { print("FAIL arith: parens"); fail = fail + 1; };
    if fail == 0 { print("OK arith"); return 0; };
    return 1;
}
