// while_let.nr — RFC-0016 sugar: `while let PATTERN = EXPR { BODY }`
// desugars to `while true { match EXPR { PATTERN => BODY, _ => break } }`.

enum Maybe { Empty, Got(i64) }

fn pop_one(state: i64) -> Maybe {
    if state > 0 { return Maybe::Got(state); };
    return Maybe::Empty;
}

fn main() -> i32 {
    let mut counter: i64 = 5;
    let mut sum: i64 = 0;
    while let Maybe::Got(v) = pop_one(counter) {
        sum = sum + v;
        counter = counter - 1;
    };
    if sum != 5 + 4 + 3 + 2 + 1 { print("FAIL: while let sum\n"); return 1; };
    print("OK while_let\n");
    return 0;
}
