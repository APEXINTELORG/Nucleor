// QM-1 -- qsim header-advertised compatibility surface.
//
// Locks qsim_prob, qsim_statevec, and qsim_copy as real public
// functions instead of comment-only promises in quantum.nr.

import "stdlib/rods/quantum.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_prob_wrapper() -> i64 {
    let sv: i64 = qsim_init(2);
    if close(qsim_prob(sv, 0, 0), f64_to_bits(1.0), 1e-9) != 1 { return 1; };
    if close(qsim_prob(sv, 0, 1), f64_to_bits(0.0), 1e-9) != 1 { return 2; };
    qsim_x(sv, 0);
    if close(qsim_prob(sv, 0, 0), f64_to_bits(0.0), 1e-9) != 1 { return 4; };
    if close(qsim_prob(sv, 0, 1), f64_to_bits(1.0), 1e-9) != 1 { return 8; };
    if close(qsim_prob(sv, 0, 99), f64_to_bits(0.0), 1e-9) != 1 { return 16; };
    return 0;
}

fn check_statevec_alias() -> i64 {
    let sv: i64 = qsim_init(3);
    let raw: i64 = qsim_statevec(sv);
    if raw != sv { return 32; };
    if qsim_num_qubits(raw) != 3 { return 64; };
    return 0;
}

fn check_copy_is_independent() -> i64 {
    let sv: i64 = qsim_init(2);
    qsim_x(sv, 0);
    let cp: i64 = qsim_copy(sv);
    if cp == 0 { return 128; };
    if cp == sv { return 256; };
    if qsim_num_qubits(cp) != 2 { return 512; };
    if close(qsim_prob(cp, 0, 1), f64_to_bits(1.0), 1e-9) != 1 { return 1024; };

    qsim_x(sv, 1);
    if close(qsim_prob(sv, 1, 1), f64_to_bits(1.0), 1e-9) != 1 { return 2048; };
    if close(qsim_prob(cp, 1, 0), f64_to_bits(1.0), 1e-9) != 1 { return 4096; };
    return 0;
}

fn check_limitations_mentions_compat() -> i64 {
    let s: str = qsim_limitations();
    if str_index_of(s, "qsim_prob") < 0 { return 8192; };
    if str_index_of(s, "qsim_statevec") < 0 { return 16384; };
    if str_index_of(s, "qsim_copy") < 0 { return 32768; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_prob_wrapper();
    fails = fails + check_statevec_alias();
    fails = fails + check_copy_is_independent();
    fails = fails + check_limitations_mentions_compat();
    return fails;
}
