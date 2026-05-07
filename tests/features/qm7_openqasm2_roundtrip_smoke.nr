// QM-7 v0843 - OpenQASM 2.0 minimal parse/round-trip smoke.
//
// Locks the qasm2_parse surface in stdlib/rods/quantum.nr against
// the deterministic emit dialect:
//   - parse on a freshly emitted program round-trips exactly
//     (qasm2_program_eq returns 1)
//   - parse on each documented header / qreg / gate failure mode
//     returns the correct stable status code
//   - parse on out-of-range qubit indices propagates
//     qasm2_status_qubit_out_of_range from the underlying emit path
//   - parse on a same-qubit cx propagates qasm2_status_same_qubit
//   - qasm2_status_parse_explain decodes every parser status code
//   - qasm2_limitations now documents the parser surface
//
// Expected: rc=0.

import "stdlib/rods/quantum.nr"
import "stdlib/rods/strings.nr"

fn build_canonical_program() -> i64 {
    let p: i64 = qasm2_program_new(3);
    if p == 0 { return 0; };
    if qasm2_emit_h(p, 0)     != qasm2_status_ok() { return 0; };
    if qasm2_emit_cx(p, 0, 1) != qasm2_status_ok() { return 0; };
    if qasm2_emit_x(p, 2)     != qasm2_status_ok() { return 0; };
    if qasm2_emit_z(p, 1)     != qasm2_status_ok() { return 0; };
    if qasm2_emit_cx(p, 2, 0) != qasm2_status_ok() { return 0; };
    return p;
}

fn check_status_codes_distinct() -> i64 {
    if qasm2_status_parse_empty_source() != 6 { return 1; };
    if qasm2_status_parse_unexpected_header() != 7 { return 2; };
    if qasm2_status_parse_malformed_qreg() != 8 { return 3; };
    if qasm2_status_parse_unsupported_gate() != 9 { return 4; };
    if qasm2_status_parse_malformed_gate() != 10 { return 5; };
    return 0;
}

fn check_round_trip_canonical() -> i64 {
    let p: i64 = build_canonical_program();
    if p == 0 { return 10; };

    let src: str = qasm2_render(p);
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_ok() { return 11; };
    let q: i64 = qasm2_parse_result_program(r);
    if q == 0 { return 12; };
    if qasm2_program_qubits(q) != 3 { return 13; };
    if qasm2_program_line_count(q) != 5 { return 14; };
    if qasm2_program_eq(p, q) != 1 { return 15; };

    // Render(q) MUST be byte-identical to Render(p).
    let src2: str = qasm2_render(q);
    if str_eq(src, src2) != 1 { return 16; };
    return 0;
}

fn check_round_trip_minimal() -> i64 {
    // Single-qubit, single-gate program.
    let p: i64 = qasm2_program_new(1);
    if p == 0 { return 20; };
    if qasm2_emit_h(p, 0) != qasm2_status_ok() { return 21; };

    let src: str = qasm2_render(p);
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_ok() { return 22; };
    let q: i64 = qasm2_parse_result_program(r);
    if qasm2_program_eq(p, q) != 1 { return 23; };
    return 0;
}

fn check_round_trip_empty_body() -> i64 {
    // No gates, just header + qreg.
    let p: i64 = qasm2_program_new(2);
    if p == 0 { return 30; };

    let src: str = qasm2_render(p);
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_ok() { return 31; };
    let q: i64 = qasm2_parse_result_program(r);
    if q == 0 { return 32; };
    if qasm2_program_qubits(q) != 2 { return 33; };
    if qasm2_program_line_count(q) != 0 { return 34; };
    if qasm2_program_eq(p, q) != 1 { return 35; };
    return 0;
}

fn check_empty_source() -> i64 {
    let r: i64 = qasm2_parse("");
    if qasm2_parse_result_status(r) != qasm2_status_parse_empty_source() { return 40; };
    if qasm2_parse_result_program(r) != 0 { return 41; };
    return 0;
}

fn check_bad_header_first_line() -> i64 {
    let src: str = "QASM 2.0;\ninclude \"qelib1.inc\";\nqreg q[1];\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_parse_unexpected_header() { return 50; };
    if qasm2_parse_result_program(r) != 0 { return 51; };
    return 0;
}

fn check_bad_header_include_line() -> i64 {
    let src: str = "OPENQASM 2.0;\ninclude \"other.inc\";\nqreg q[1];\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_parse_unexpected_header() { return 60; };
    return 0;
}

fn check_truncated_header() -> i64 {
    // Truncated source missing the qreg slot: split produces three
    // parts (two header lines + trailing empty after final '\n'), so
    // the parser hits the qreg slot and reports malformed_qreg, not
    // unexpected_header. Lock that contract here.
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_parse_malformed_qreg() { return 70; };
    return 0;
}

fn check_truncated_header_two_lines_only() -> i64 {
    // No trailing newline => split yields exactly 2 parts, so we
    // get parse_unexpected_header (nparts < 3 path).
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_parse_unexpected_header() { return 71; };
    return 0;
}

fn check_malformed_qreg_missing_brackets() -> i64 {
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";\nqreg q3];\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_parse_malformed_qreg() { return 80; };
    return 0;
}

fn check_malformed_qreg_non_digit() -> i64 {
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";\nqreg q[xx];\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_parse_malformed_qreg() { return 90; };
    return 0;
}

fn check_malformed_qreg_zero() -> i64 {
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";\nqreg q[0];\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_parse_malformed_qreg() { return 100; };
    return 0;
}

fn check_qreg_above_cap() -> i64 {
    // qasm2_max_qubits() = 1024 per the emit-side cap; 1025 should
    // map to qasm2_status_invalid_qubit_count.
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";\nqreg q[1025];\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_invalid_qubit_count() { return 110; };
    return 0;
}

fn check_unsupported_gate() -> i64 {
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";\nqreg q[2];\ny q[0];\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_parse_unsupported_gate() { return 120; };
    if qasm2_parse_result_program(r) != 0 { return 121; };
    return 0;
}

fn check_malformed_gate_line() -> i64 {
    // The h-prefix matches but the "];" suffix is missing, so
    // _qasm2_parse_1q_arg returns -1 and the parser surfaces
    // qasm2_status_parse_malformed_gate (not parse_unsupported_gate).
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";\nqreg q[2];\nh q[0\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_parse_malformed_gate() { return 140; };
    return 0;
}

fn check_cx_malformed_args() -> i64 {
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";\nqreg q[3];\ncx q[0];\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_parse_malformed_gate() { return 150; };
    return 0;
}

fn check_qubit_out_of_range_propagates() -> i64 {
    // qreg q[2] -> only qubits 0,1 valid. References q[2] in body.
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";\nqreg q[2];\nh q[2];\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_qubit_out_of_range() { return 160; };
    return 0;
}

fn check_same_qubit_propagates() -> i64 {
    let src: str = "OPENQASM 2.0;\ninclude \"qelib1.inc\";\nqreg q[2];\ncx q[0],q[0];\n";
    let r: i64 = qasm2_parse(src);
    if qasm2_parse_result_status(r) != qasm2_status_same_qubit() { return 170; };
    return 0;
}

fn check_status_explain_text() -> i64 {
    if str_eq(qasm2_status_parse_explain(qasm2_status_parse_empty_source()), "parse_empty_source") != 1 { return 180; };
    if str_eq(qasm2_status_parse_explain(qasm2_status_parse_unexpected_header()), "parse_unexpected_header") != 1 { return 181; };
    if str_eq(qasm2_status_parse_explain(qasm2_status_parse_malformed_qreg()), "parse_malformed_qreg") != 1 { return 182; };
    if str_eq(qasm2_status_parse_explain(qasm2_status_parse_unsupported_gate()), "parse_unsupported_gate") != 1 { return 183; };
    if str_eq(qasm2_status_parse_explain(qasm2_status_parse_malformed_gate()), "parse_malformed_gate") != 1 { return 184; };
    // Falls through to qasm2_status_explain for non-parser codes.
    if str_eq(qasm2_status_parse_explain(qasm2_status_ok()), "ok") != 1 { return 185; };
    if str_eq(qasm2_status_parse_explain(qasm2_status_qubit_out_of_range()), "qubit_out_of_range") != 1 { return 186; };
    return 0;
}

fn check_limitations_mentions_parser() -> i64 {
    let s: str = qasm2_limitations();
    if str_index_of(s, "qasm2_parse(src)") < 0 { return 190; };
    if str_index_of(s, "Round-trip") < 0 { return 191; };
    if str_index_of(s, "parse_empty_source") < 0 { return 192; };
    if str_index_of(s, "parse_unsupported_gate") < 0 { return 193; };
    if str_index_of(s, "qasm2_parse_result_status") < 0 { return 194; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_status_codes_distinct();
    fails = fails + check_round_trip_canonical();
    fails = fails + check_round_trip_minimal();
    fails = fails + check_round_trip_empty_body();
    fails = fails + check_empty_source();
    fails = fails + check_bad_header_first_line();
    fails = fails + check_bad_header_include_line();
    fails = fails + check_truncated_header();
    fails = fails + check_truncated_header_two_lines_only();
    fails = fails + check_malformed_qreg_missing_brackets();
    fails = fails + check_malformed_qreg_non_digit();
    fails = fails + check_malformed_qreg_zero();
    fails = fails + check_qreg_above_cap();
    fails = fails + check_unsupported_gate();
    fails = fails + check_malformed_gate_line();
    fails = fails + check_cx_malformed_args();
    fails = fails + check_qubit_out_of_range_propagates();
    fails = fails + check_same_qubit_propagates();
    fails = fails + check_status_explain_text();
    fails = fails + check_limitations_mentions_parser();
    return fails;
}
