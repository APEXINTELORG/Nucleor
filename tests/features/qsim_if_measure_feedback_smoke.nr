// v0854 QM-17 - qsim mid-circuit measurement feedback.
//
// Locks deterministic then/else feedback branches. The measured qubit is
// prepared in a basis state so the smoke does not depend on RNG distribution.

import "stdlib/rods/quantum.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_then_branch() -> i64 {
    let sv: i64 = qsim_init_checked(2);
    qsim_x(sv, 0);

    let out: i64 = qsim_if_measure(
        sv,
        0,
        1,
        qsim_feedback_gate_x(),
        1,
        qsim_feedback_gate_none(),
        1,
        f64_to_bits(0.0)
    );

    if out != 1 { return 1; };
    if close(qsim_prob(sv, 1, 1), f64_to_bits(1.0), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_else_branch() -> i64 {
    let sv: i64 = qsim_init_checked(2);

    let out: i64 = qsim_if_measure(
        sv,
        0,
        1,
        qsim_feedback_gate_none(),
        1,
        qsim_feedback_gate_x(),
        1,
        f64_to_bits(0.0)
    );

    if out != 0 { return 4; };
    if close(qsim_prob(sv, 1, 1), f64_to_bits(1.0), 1e-9) != 1 { return 8; };
    return 0;
}

fn check_status_and_text() -> i64 {
    let sv: i64 = qsim_init_checked(1);
    let bad_expected: i64 = qsim_if_measure(
        sv,
        0,
        2,
        qsim_feedback_gate_none(),
        0,
        qsim_feedback_gate_none(),
        0,
        f64_to_bits(0.0)
    );
    if bad_expected != 0 - 1 { return 16; };

    let bad_gate: i64 = qsim_if_measure(
        sv,
        0,
        0,
        999,
        0,
        qsim_feedback_gate_none(),
        0,
        f64_to_bits(0.0)
    );
    if bad_gate != 0 - 2 { return 32; };

    let s: str = qsim_limitations();
    if str_index_of(s, "QM-17") < 0 { return 64; };
    if str_index_of(s, "qsim_if_measure") < 0 { return 128; };
    if str_index_of(s, "MID-CIRCUIT FEEDBACK") < 0 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_then_branch();
    fails = fails + check_else_branch();
    fails = fails + check_status_and_text();
    return fails;
}
