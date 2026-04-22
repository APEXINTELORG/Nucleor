// loop_kw.nr — `loop { BODY }` desugars to `while true { BODY }`.

fn main() -> i32 {
    let mut count: i64 = 0;
    loop {
        count = count + 1;
        if count >= 5 { break; };
    };
    if count != 5 { print("FAIL: loop count\n"); return 1; };

    let mut sum: i64 = 0;
    let mut i: i64 = 0;
    loop {
        if i >= 10 { break; };
        sum = sum + i;
        i = i + 1;
    };
    if sum != 45 { print("FAIL: loop sum\n"); return 1; };

    print("OK loop_kw\n");
    return 0;
}
