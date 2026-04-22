// control_flow.nr — if/else, while, return
fn classify(n: i64) -> i64 {
    if n < 0 { return -1; };
    if n == 0 { return 0; };
    return 1;
}

fn sum_to(n: i64) -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 1;
    while i <= n {
        acc = acc + i;
        i = i + 1;
    };
    return acc;
}

fn main() -> i64 {
    let mut fail: i64 = 0;
    if classify(-5) != -1 { print("FAIL control: classify neg"); fail = fail + 1; };
    if classify(0) != 0 { print("FAIL control: classify zero"); fail = fail + 1; };
    if classify(7) != 1 { print("FAIL control: classify pos"); fail = fail + 1; };
    if sum_to(10) != 55 { print("FAIL control: sum_to 10"); fail = fail + 1; };
    if sum_to(100) != 5050 { print("FAIL control: sum_to 100"); fail = fail + 1; };

    // else if chain
    let n: i64 = 42;
    let mut tag: i64 = -1;
    if n < 10 { tag = 0; } else { if n < 100 { tag = 1; } else { tag = 2; }; };
    if tag != 1 { print("FAIL control: else-if"); fail = fail + 1; };

    if fail == 0 { print("OK control_flow"); return 0; };
    return 1;
}
