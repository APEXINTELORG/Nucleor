// if_let.nr — RFC-0016 sugar: `if let PATTERN = EXPR { THEN } else { ELSE }`
// desugars to a single-arm match.

enum Opt { None, Some(i64) }

fn classify(o: Opt) -> i64 {
    if let Opt::Some(x) = o { return x + 1; } else { return 0; };
}

fn classify3(o: Opt) -> i64 {
    let mut result: i64 = 99;
    if let Opt::Some(v) = o { result = v; };
    return result;
}

fn main() -> i32 {
    let mut fail: i64 = 0;

    if classify(Opt::Some(42)) != 43 { fail = fail + 1; print("FAIL: classify Some\n"); };
    if classify(Opt::None) != 0 { fail = fail + 1; print("FAIL: classify None\n"); };
    if classify3(Opt::Some(33)) != 33 { fail = fail + 1; print("FAIL: classify3 Some\n"); };
    if classify3(Opt::None) != 99 { fail = fail + 1; print("FAIL: classify3 None\n"); };

    if fail == 0 { print("OK if_let\n"); return 0; };
    return 1;
}
