// t453_for_iter_method_print.nr // v0.3.187 regression fixture.
//
// Sister fix to v0.3.175 (for-loop variable type registration).
// `for n in v.iter() { print(n); }` SIGSEGV'd because the
// indexed_element_full_type lookup on the iter() method call
// (kind 8) failed // iter() is identity pass-through (per
// t364) but indexed_element_full_type doesn't recognize the
// builtin method, so it returned "" and __type_n was never
// registered. print(n) then fell through to print_str.
//
// Same hazard class as v0.3.175 (for-loop var) and v0.3.176-186
// (var/binding type registration).
//
// Fix (v0.3.187): in the for-loop kind-49 (iter form) lowering,
// when the receiver is a kind 8 (method call) with mname `iter`
// or `into_iter`, strip the method call and look up the
// ELEMENT type from the underlying receiver Vec. Reuses the
// existing indexed_element_full_type helper.

fn main() -> i64 {
    let mut nums: Vec<i64> = Vec::new();
    nums.push(10); nums.push(20); nums.push(30);
    for n in nums.iter() {
        print(n);                  // pre-fix SIGSEGV
    }

    let mut strs: Vec<str> = Vec::new();
    strs.push("alpha"); strs.push("beta");
    for s in strs.iter() {
        print(s);                  // pre-fix SIGSEGV (and via str dispatch)
    }

    return 42;
}
