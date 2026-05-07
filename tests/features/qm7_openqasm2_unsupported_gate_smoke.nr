// QM-7 v0842 - OpenQASM 2.0 unsupported-gate refusal smoke.
//
// Locks that name-dispatched emit refuses every name outside the
// minimum supported subset {h, x, z, cx} with stable status code 4
// (qasm2_status_unsupported_gate) WITHOUT mutating the program.
//
// Expected: rc=0.

import "stdlib/rods/quantum.nr"
import "stdlib/rods/strings.nr"

fn check_supported_predicate_subset() -> i64 {
    if qasm2_supported_gate("h")  != 1 { return 1; };
    if qasm2_supported_gate("x")  != 1 { return 2; };
    if qasm2_supported_gate("z")  != 1 { return 3; };
    if qasm2_supported_gate("cx") != 1 { return 4; };
    if qasm2_supported_gate("y")  != 0 { return 5; };
    if qasm2_supported_gate("s")  != 0 { return 6; };
    if qasm2_supported_gate("t")  != 0 { return 7; };
    if qasm2_supported_gate("rz") != 0 { return 8; };
    if qasm2_supported_gate("rx") != 0 { return 9; };
    if qasm2_supported_gate("ry") != 0 { return 10; };
    if qasm2_supported_gate("ccx") != 0 { return 11; };
    if qasm2_supported_gate("swap") != 0 { return 12; };
    if qasm2_supported_gate("")    != 0 { return 13; };
    return 0;
}

fn check_named_1q_unsupported_codes() -> i64 {
    let p: i64 = qasm2_program_new(3);
    if p == 0 { return 20; };
    if qasm2_emit_named_1q(p, "y", 0)  != qasm2_status_unsupported_gate() { return 21; };
    if qasm2_emit_named_1q(p, "s", 1)  != qasm2_status_unsupported_gate() { return 22; };
    if qasm2_emit_named_1q(p, "t", 2)  != qasm2_status_unsupported_gate() { return 23; };
    if qasm2_emit_named_1q(p, "rz", 0) != qasm2_status_unsupported_gate() { return 24; };
    if qasm2_emit_named_1q(p, "id", 0) != qasm2_status_unsupported_gate() { return 25; };
    if qasm2_emit_named_1q(p, "",  0)  != qasm2_status_unsupported_gate() { return 26; };
    // None of the unsupported requests should have appended a body line.
    if qasm2_program_line_count(p) != 0 { return 27; };
    return 0;
}

fn check_named_2q_unsupported_codes() -> i64 {
    let p: i64 = qasm2_program_new(3);
    if p == 0 { return 30; };
    if qasm2_emit_named_2q(p, "cz",   0, 1) != qasm2_status_unsupported_gate() { return 31; };
    if qasm2_emit_named_2q(p, "swap", 0, 1) != qasm2_status_unsupported_gate() { return 32; };
    if qasm2_emit_named_2q(p, "ccx",  0, 1) != qasm2_status_unsupported_gate() { return 33; };
    if qasm2_emit_named_2q(p, "h",    0, 1) != qasm2_status_unsupported_gate() { return 34; };
    if qasm2_emit_named_2q(p, "",     0, 1) != qasm2_status_unsupported_gate() { return 35; };
    if qasm2_program_line_count(p) != 0 { return 36; };
    return 0;
}

fn check_named_dispatch_does_not_corrupt_render() -> i64 {
    let p: i64 = qasm2_program_new(2);
    if p == 0 { return 40; };

    if qasm2_emit_named_1q(p, "h", 0) != qasm2_status_ok() { return 41; };
    if qasm2_emit_named_2q(p, "cx", 0, 1) != qasm2_status_ok() { return 42; };

    // Interleave several rejected requests; they must not mutate state.
    if qasm2_emit_named_1q(p, "y", 0)   != qasm2_status_unsupported_gate() { return 43; };
    if qasm2_emit_named_2q(p, "swap", 0, 1) != qasm2_status_unsupported_gate() { return 44; };

    if qasm2_emit_named_1q(p, "z", 1) != qasm2_status_ok() { return 45; };

    if qasm2_program_line_count(p) != 3 { return 46; };

    let src: str = qasm2_render(p);
    if strings_contains(src, "h q[0];\n") != 1 { return 47; };
    if strings_contains(src, "cx q[0],q[1];\n") != 1 { return 48; };
    if strings_contains(src, "z q[1];\n") != 1 { return 49; };
    // Rejected names must not appear in the rendered source.
    if strings_contains(src, "y q[")    != 0 { return 50; };
    if strings_contains(src, "swap ")   != 0 { return 51; };
    return 0;
}

fn check_status_explain_unsupported() -> i64 {
    if str_eq(qasm2_status_explain(qasm2_status_unsupported_gate()), "unsupported_gate") != 1 { return 60; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_supported_predicate_subset();
    fails = fails + check_named_1q_unsupported_codes();
    fails = fails + check_named_2q_unsupported_codes();
    fails = fails + check_named_dispatch_does_not_corrupt_render();
    fails = fails + check_status_explain_unsupported();
    return fails;
}
