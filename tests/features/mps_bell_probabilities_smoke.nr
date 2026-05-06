// v0832 QM-6 - MPS Bell marginal, joint, and statevector smoke.
//
// Locks the MPS probability readout against the existing statevector qsim
// path for a 2-qubit Bell circuit: H(0), CNOT(0,1). Expected: each qubit has
// P(0)=0.5 and <Z>=0 in both simulators' marginal view. Also locks the
// MPS computational-basis joint probability readout for |00> and |11>, plus
// the capped qsim-compatible Vec<complex> statevector extraction surface.

import "stdlib/rods/mps.nr"
import "stdlib/rods/quantum.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_mps_bell_marginals() -> i64 {
    let h: i64 = mps_init(2, 16);
    mps_h(h, 0);
    mps_cnot(h, 0, 1);

    let p0: i64 = mps_prob0(h, 0);
    let p1: i64 = mps_prob0(h, 1);
    let z0: i64 = mps_expect_z(h, 0);
    let z1: i64 = mps_expect_z(h, 1);
    let mb: i64 = mps_max_bond(h);
    mps_free(h);

    if close(p0, f64_to_bits(0.5), 1e-6) != 1 { return 1; };
    if close(p1, f64_to_bits(0.5), 1e-6) != 1 { return 2; };
    if close(z0, f64_to_bits(0.0), 1e-6) != 1 { return 4; };
    if close(z1, f64_to_bits(0.0), 1e-6) != 1 { return 8; };
    if mb < 2 { return 16; };
    return 0;
}

fn check_mps_bell_joint_probabilities() -> i64 {
    let h: i64 = mps_init(2, 16);
    mps_h(h, 0);
    mps_cnot(h, 0, 1);

    let p00: i64 = mps_prob_basis(h, 0);
    let p01: i64 = mps_prob_basis(h, 1);
    let p10: i64 = mps_prob_basis(h, 2);
    let p11: i64 = mps_prob_basis(h, 3);
    let p_over: i64 = mps_prob_basis(h, 4);
    mps_free(h);

    if close(p00, f64_to_bits(0.5), 1e-6) != 1 { return 2048; };
    if close(p01, f64_to_bits(0.0), 1e-6) != 1 { return 4096; };
    if close(p10, f64_to_bits(0.0), 1e-6) != 1 { return 8192; };
    if close(p11, f64_to_bits(0.5), 1e-6) != 1 { return 16384; };
    if close(p_over, f64_to_bits(0.0), 1e-6) != 1 { return 32768; };
    return 0;
}

fn check_mps_bell_statevector() -> i64 {
    let h: i64 = mps_init(2, 16);
    mps_h(h, 0);
    mps_cnot(h, 0, 1);

    let sv: i64 = mps_statevector(h);
    mps_free(h);
    if sv == 0 { return 262144; };
    if vec_len(sv) != 4 { return 524288; };

    let a00: i64 = vec_get(sv, 0);
    let a01: i64 = vec_get(sv, 1);
    let a10: i64 = vec_get(sv, 2);
    let a11: i64 = vec_get(sv, 3);

    if close(cx_real(a00), f64_to_bits(0.7071067811865476), 1e-6) != 1 { return 1048576; };
    if close(cx_imag(a00), f64_to_bits(0.0), 1e-6) != 1 { return 2097152; };
    if close(cx_real(a01), f64_to_bits(0.0), 1e-6) != 1 { return 4194304; };
    if close(cx_imag(a01), f64_to_bits(0.0), 1e-6) != 1 { return 8388608; };
    if close(cx_real(a10), f64_to_bits(0.0), 1e-6) != 1 { return 16777216; };
    if close(cx_imag(a10), f64_to_bits(0.0), 1e-6) != 1 { return 33554432; };
    if close(cx_real(a11), f64_to_bits(0.7071067811865476), 1e-6) != 1 { return 67108864; };
    if close(cx_imag(a11), f64_to_bits(0.0), 1e-6) != 1 { return 134217728; };
    return 0;
}

fn check_mps_statevector_cap() -> i64 {
    let cap: i64 = mps_statevector_max_qubits();
    if cap < 2 { return 268435456; };

    let h: i64 = mps_init(cap + 1, 16);
    let sv: i64 = mps_statevector(h);
    mps_free(h);
    if sv != 0 { return 536870912; };
    return 0;
}

fn check_qsim_reference_marginals() -> i64 {
    let sv: i64 = qsim_init_checked(2);
    if sv == 0 { return 32; };
    qsim_h(sv, 0);
    qsim_cnot(sv, 0, 1);

    let p0: i64 = qsim_prob0(sv, 0);
    let p1: i64 = qsim_prob0(sv, 1);
    if close(p0, f64_to_bits(0.5), 1e-6) != 1 { return 64; };
    if close(p1, f64_to_bits(0.5), 1e-6) != 1 { return 128; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = mps_limitations();
    if str_index_of(s, "QM-6") < 0 { return 256; };
    if str_index_of(s, "mps_prob0") < 0 { return 512; };
    if str_index_of(s, "mps_prob_basis") < 0 { return 65536; };
    if str_index_of(s, "joint-probability") < 0 { return 1024; };
    if str_index_of(s, "mps_statevector") < 0 { return 131072; };
    if str_index_of(s, "memory blowups") < 0 { return 1073741824; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_mps_bell_marginals();
    fails = fails + check_mps_bell_joint_probabilities();
    fails = fails + check_mps_bell_statevector();
    fails = fails + check_mps_statevector_cap();
    fails = fails + check_qsim_reference_marginals();
    fails = fails + check_limitations();
    return fails;
}
