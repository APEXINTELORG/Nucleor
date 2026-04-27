// t470_multi_multi_dispatch.nr -- v0.3.235 regression pin for
// RFC-NRT-004 §C (Nucleor_Translate).
//
// Reported against v0.3.231 as CRITICAL silent miscompute: when
// a recursive enum had two or more multi-payload variants,
// constructing variants beyond the first multi-payload one
// dispatched at runtime to the FIRST multi-payload arm body --
// the build succeeded but the discriminant tag was misidentified.
// Reproducer below: `dispatch_test(binop)` returned 200 (the
// `Call` arm) instead of 300 in v0.3.231.
//
// Status by the time this fixture lands (v0.3.235): the bug no
// longer reproduces. Pinned here with the EXACT RFC repro shape
// so any regression in variant-tag emission for multi-payload
// recursive variants will be caught by the verify gate.
//
// Acceptance criterion from the RFC: this fixture returns 0 from
// `test_dispatch_correctness`.

pub enum E {
    Single,
    Call(str, E),
    BinOp(str, E, E),
}

fn dispatch_test(e: E) -> i64 {
    match e {
        E::Single => return 100,
        E::Call(name, arg) => return 200,
        E::BinOp(op, lhs, rhs) => return 300,
    };
}

fn test_dispatch_correctness() -> i64 {
    let single: E = E::Single;
    let call: E = E::Call("foo", E::Single);
    let binop: E = E::BinOp("+", E::Single, E::Single);
    if dispatch_test(single) != 100 { return 1; };
    if dispatch_test(call) != 200 { return 1; };
    if dispatch_test(binop) != 300 { return 1; };
    return 0;
}

fn main() -> i64 {
    return test_dispatch_correctness();
}
