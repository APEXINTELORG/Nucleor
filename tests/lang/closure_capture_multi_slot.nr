// closure_capture_multi_slot.nr — multiple captures in one closure must occupy distinct slots.
//
// A single closure that captures two distinct locals must read both
// values correctly. This passes today and is a guard against the
// per-instance fix accidentally collapsing multi-slot indexing.

fn main() -> i64 {
    let mut fail: i64 = 0;
    let a: i64 = 7;
    let b: i64 = 5;
    let f: i64 = |x| x * a + b;

    if f(3)  != 26 { print("FAIL closure_capture_multi_slot: f(3) = 3*7+5 = 26"); fail = fail + 1; };
    if f(10) != 75 { print("FAIL closure_capture_multi_slot: f(10) = 10*7+5 = 75"); fail = fail + 1; };

    if fail == 0 { print("OK closure_capture_multi_slot"); return 0; };
    return 1;
}
