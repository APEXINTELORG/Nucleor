// v0.4.125: extended Vec/iterator surface — 5 new methods on top
// of v0.4.101's chain baseline:
//   position(pred) -> i64    — index of first match, or -1
//   product()      -> i64    — multiplies all elements (1 if empty)
//   step_by(n)     -> Vec    — every n-th element
//   nth(n)         -> i64    — n-th element (panics OOB)
//   reduce(fn)     -> i64    — like fold but uses first elem as init
// All routed through new __nucleor_vec_*_i64 runtime helpers in
// nucleor_llvm_rt.c with the standard 5-table mirror. Audit
// doc-#1 §6 closer (still partial — full Iterator trait is v0.5).

fn is_even(x: i64) -> i64 { if x % 2 == 0 { 1 } else { 0 } }
fn add(a: i64, b: i64) -> i64 { a + b }

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1); v.push(2); v.push(3); v.push(4); v.push(5);
    print_int(v.position(is_even));
    print_int(v.product());
    let s: Vec<i64> = v.step_by(2);
    print_int(s.len());
    print_int(v.nth(2));
    print_int(v.reduce(add));
    0
}
