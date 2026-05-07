// QM-7 v0842 - OpenQASM 2.0 emit-only smoke.
//
// Locks the minimal qasm2_* surface in stdlib/rods/quantum.nr:
//   - program lifecycle: new / qubits / line_count
//   - emit_h / emit_x / emit_z / emit_cx success paths return ok
//   - render produces a deterministic 'OPENQASM 2.0;' + qelib1.inc +
//     qreg q[3]; preamble plus per-line gate body
//   - qubit-out-of-range and same-qubit CX fail with stable status codes
//   - status_explain decodes each emitted status code
//
// Expected: rc=0.

import "stdlib/rods/quantum.nr"
import "stdlib/rods/strings.nr"

fn check_lifecycle() -> i64 {
    if qasm2_program_new(0) != 0 { return 1; };
    if qasm2_program_new(0 - 1) != 0 { return 2; };
    if qasm2_program_new(qasm2_max_qubits() + 1) != 0 { return 3; };

    let p: i64 = qasm2_program_new(3);
    if p == 0 { return 4; };
    if qasm2_program_qubits(p) != 3 { return 5; };
    if qasm2_program_line_count(p) != 0 { return 6; };
    return 0;
}

fn check_status_constants() -> i64 {
    if qasm2_status_ok() != 0 { return 10; };
    if qasm2_status_invalid_program() != 1 { return 11; };
    if qasm2_status_qubit_out_of_range() != 2 { return 12; };
    if qasm2_status_same_qubit() != 3 { return 13; };
    if qasm2_status_unsupported_gate() != 4 { return 14; };
    if qasm2_status_invalid_qubit_count() != 5 { return 15; };
    return 0;
}

fn check_emit_supported() -> i64 {
    let p: i64 = qasm2_program_new(3);
    if p == 0 { return 20; };
    if qasm2_emit_h(p, 0) != qasm2_status_ok() { return 21; };
    if qasm2_emit_x(p, 1) != qasm2_status_ok() { return 22; };
    if qasm2_emit_z(p, 2) != qasm2_status_ok() { return 23; };
    if qasm2_emit_cx(p, 0, 1) != qasm2_status_ok() { return 24; };
    if qasm2_program_line_count(p) != 4 { return 25; };
    return 0;
}

fn check_emit_named_dispatch() -> i64 {
    let p: i64 = qasm2_program_new(2);
    if p == 0 { return 30; };
    if qasm2_emit_named_1q(p, "h", 0) != qasm2_status_ok() { return 31; };
    if qasm2_emit_named_1q(p, "x", 1) != qasm2_status_ok() { return 32; };
    if qasm2_emit_named_2q(p, "cx", 0, 1) != qasm2_status_ok() { return 33; };
    if qasm2_program_line_count(p) != 3 { return 34; };
    if qasm2_supported_gate("h") != 1 { return 35; };
    if qasm2_supported_gate("cx") != 1 { return 36; };
    if qasm2_supported_gate("y") != 0 { return 37; };
    return 0;
}

fn check_emit_failure_paths() -> i64 {
    let p: i64 = qasm2_program_new(2);
    if p == 0 { return 40; };
    if qasm2_emit_h(p, 0 - 1) != qasm2_status_qubit_out_of_range() { return 41; };
    if qasm2_emit_h(p, 2)     != qasm2_status_qubit_out_of_range() { return 42; };
    if qasm2_emit_cx(p, 0, 0) != qasm2_status_same_qubit() { return 43; };
    if qasm2_emit_cx(p, 0, 5) != qasm2_status_qubit_out_of_range() { return 44; };
    if qasm2_emit_h(0, 0)     != qasm2_status_invalid_program() { return 45; };
    if qasm2_emit_cx(0, 0, 1) != qasm2_status_invalid_program() { return 46; };
    if qasm2_program_line_count(p) != 0 { return 47; };
    return 0;
}

fn check_render_preamble_and_body() -> i64 {
    let p: i64 = qasm2_program_new(3);
    if p == 0 { return 50; };
    if qasm2_emit_h(p, 0)      != qasm2_status_ok() { return 51; };
    if qasm2_emit_cx(p, 0, 1)  != qasm2_status_ok() { return 52; };
    if qasm2_emit_x(p, 2)      != qasm2_status_ok() { return 53; };
    if qasm2_emit_z(p, 1)      != qasm2_status_ok() { return 54; };

    let src: str = qasm2_render(p);
    if strings_starts_with(src, "OPENQASM 2.0;\n") != 1 { return 55; };
    if strings_contains(src, "include \"qelib1.inc\";\n") != 1 { return 56; };
    if strings_contains(src, "qreg q[3];\n") != 1 { return 57; };
    if strings_contains(src, "h q[0];\n") != 1 { return 58; };
    if strings_contains(src, "cx q[0],q[1];\n") != 1 { return 59; };
    if strings_contains(src, "x q[2];\n") != 1 { return 60; };
    if strings_contains(src, "z q[1];\n") != 1 { return 61; };
    if strings_ends_with(src, "z q[1];\n") != 1 { return 62; };
    return 0;
}

fn check_status_explain_text() -> i64 {
    if str_eq(qasm2_status_explain(qasm2_status_ok()), "ok") != 1 { return 70; };
    if str_eq(qasm2_status_explain(qasm2_status_invalid_program()), "invalid_program") != 1 { return 71; };
    if str_eq(qasm2_status_explain(qasm2_status_qubit_out_of_range()), "qubit_out_of_range") != 1 { return 72; };
    if str_eq(qasm2_status_explain(qasm2_status_same_qubit()), "same_qubit") != 1 { return 73; };
    if str_eq(qasm2_status_explain(qasm2_status_unsupported_gate()), "unsupported_gate") != 1 { return 74; };
    if str_eq(qasm2_status_explain(qasm2_status_invalid_qubit_count()), "invalid_qubit_count") != 1 { return 75; };
    if str_eq(qasm2_status_explain(0 - 99), "unknown") != 1 { return 76; };
    return 0;
}

fn check_limitations_text() -> i64 {
    let s: str = qasm2_limitations();
    if str_index_of(s, "QM-7") < 0 { return 80; };
    if str_index_of(s, "EMIT-ONLY") < 0 { return 81; };
    if str_index_of(s, "H/X/Z/CX") < 0 { return 82; };
    if str_index_of(s, "qasm2_max_qubits") < 0 { return 83; };
    if str_index_of(s, "qasm2_status_unsupported_gate") < 0 { return 84; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_lifecycle();
    fails = fails + check_status_constants();
    fails = fails + check_emit_supported();
    fails = fails + check_emit_named_dispatch();
    fails = fails + check_emit_failure_paths();
    fails = fails + check_render_preamble_and_body();
    fails = fails + check_status_explain_text();
    fails = fails + check_limitations_text();
    return fails;
}
