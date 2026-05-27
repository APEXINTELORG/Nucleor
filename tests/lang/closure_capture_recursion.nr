// closure_capture_recursion.nr — distinct closure instances must not share captures.
//
// Two calls to a function that produces a capturing closure literal must
// produce two values whose captures are independent. Today they collide
// on a single global slot keyed by the closure literal's lex-time id.

fn apply(f: i64, x: i64) -> i64 { return f(x); }

fn make_doubler(k: i64) -> i64 {
    let g: i64 = |x| x * k;
    return g;
}

fn main() -> i64 {
    let mut fail: i64 = 0;
    let g10:  i64 = make_doubler(10);
    let g100: i64 = make_doubler(100);

    let a: i64 = apply(g10,  2);
    let b: i64 = apply(g100, 2);

    if a != 20  { print("FAIL closure_capture_recursion: outer instance stomped"); fail = fail + 1; };
    if b != 200 { print("FAIL closure_capture_recursion: inner instance wrong"); fail = fail + 1; };

    if fail == 0 { print("OK closure_capture_recursion"); return 0; };
    return 1;
}
