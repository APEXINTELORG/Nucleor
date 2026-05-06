// v0855 QM-16 - qsim trajectory noise surface.
//
// Uses deterministic p=0 and p=1 cases so the smoke is stable while still
// locking caller-controlled noise injection.

import "stdlib/rods/quantum.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_bit_flip_noise() -> i64 {
    let sv0: i64 = qsim_init_checked(1);
    if qsim_noise_bit_flip(sv0, 0, f64_to_bits(0.0)) != qsim_noise_status_ok() { return 1; };
    if close(qsim_prob(sv0, 0, 0), f64_to_bits(1.0), 1e-9) != 1 { return 2; };

    let sv1: i64 = qsim_init_checked(1);
    if qsim_noise_bit_flip(sv1, 0, f64_to_bits(1.0)) != qsim_noise_status_ok() { return 4; };
    if close(qsim_prob(sv1, 0, 1), f64_to_bits(1.0), 1e-9) != 1 { return 8; };
    return 0;
}

fn check_dephase_noise() -> i64 {
    let sv0: i64 = qsim_init_checked(1);
    qsim_h(sv0, 0);
    if qsim_noise_dephase(sv0, 0, f64_to_bits(0.0)) != qsim_noise_status_ok() { return 16; };
    qsim_h(sv0, 0);
    if close(qsim_prob(sv0, 0, 0), f64_to_bits(1.0), 1e-9) != 1 { return 32; };

    let sv1: i64 = qsim_init_checked(1);
    qsim_h(sv1, 0);
    if qsim_noise_dephase(sv1, 0, f64_to_bits(1.0)) != qsim_noise_status_ok() { return 64; };
    qsim_h(sv1, 0);
    if close(qsim_prob(sv1, 0, 1), f64_to_bits(1.0), 1e-9) != 1 { return 128; };
    return 0;
}

fn check_depolarizing_status_and_text() -> i64 {
    let sv: i64 = qsim_init_checked(1);
    if qsim_noise_depolarizing(sv, 0, f64_to_bits(0.0)) != qsim_noise_status_ok() { return 256; };
    if close(qsim_prob(sv, 0, 0), f64_to_bits(1.0), 1e-9) != 1 { return 512; };
    if qsim_noise_bit_flip(sv, 0, f64_to_bits(0.0 - 1.0)) != qsim_noise_status_invalid_probability() { return 1024; };
    if qsim_noise_dephase(sv, 0, f64_to_bits(2.0)) != qsim_noise_status_invalid_probability() { return 2048; };

    let s: str = qsim_limitations();
    if str_index_of(s, "QM-16") < 0 { return 4096; };
    if str_index_of(s, "qsim_noise_dephase") < 0 { return 8192; };
    if str_index_of(s, "TRAJECTORY NOISE") < 0 { return 16384; };
    if str_index_of(s, "not a full density-matrix") < 0 { return 32768; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_bit_flip_noise();
    fails = fails + check_dephase_noise();
    fails = fails + check_depolarizing_status_and_text();
    return fails;
}
