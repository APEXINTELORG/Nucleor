// v0.6.86 RFC V1.4 (correctness): the != opcode in the auto-
// dispatch path was using ir_binop_t(2, ...) (add) instead of (3)
// (sub), so `1 - eq` actually computed `1 + eq`. The bug surfaced
// when nested struct fields routed through their own derived-eq:
// outer's `a != b` where Inner has `#[derive(PartialEq)]` produced
// `add 1, eq_result` instead of `sub 1, eq_result`, inverting the
// inner !=. Fix: use opcode 3 (sub).
//
// Recursive-derive case: when both Outer and Inner derive
// PartialEq, the auto-generated Outer__derived_eq's per-field
// `!= a.<field> != b.<field>` correctly routes to Inner's helper.
#[derive(PartialEq)]
struct Inner { v: i64 }

#[derive(PartialEq)]
struct Outer { a: Inner, b: i64 }

fn main() -> i32 {
    let p: Outer = Outer { a: Inner { v: 5 }, b: 7 };
    let q: Outer = Outer { a: Inner { v: 5 }, b: 7 };
    let r: Outer = Outer { a: Inner { v: 6 }, b: 7 };
    if p == q { print_int(11); } else { print_int(0); };
    if p == r { print_int(0); } else { print_int(22); };
    if p != r { print_int(33); } else { print_int(0); };
    return 0;
}
