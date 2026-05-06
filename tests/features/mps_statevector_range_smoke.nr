// v0835 QM-6 - bounded MPS statevector range extraction.
//
// Locks high-qubit MPS amplitude readout without raising the full-state
// materialization cap. The range API returns only caller-capped windows of
// computational-basis amplitudes and fails closed outside the addressable range.

import "stdlib/rods/mps.nr"
import "stdlib/rods/complex.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_product_state_high_qubit_range() -> i64 {
    let n: i64 = mps_statevector_max_qubits() + 4;
    let h: i64 = mps_init(n, 16);
    if h == 0 { return 1; };

    let full: i64 = mps_statevector(h);
    if full != 0 { mps_free(h); return 2; };

    let r: i64 = mps_statevector_range(h, 0, 4);
    mps_free(h);
    if r == 0 { return 4; };
    if vec_len(r) != 4 { return 8; };

    if close(cx_real(vec_get(r, 0)), f64_to_bits(1.0), 0.000001) != 1 { return 16; };
    if close(cx_imag(vec_get(r, 0)), f64_to_bits(0.0), 0.000001) != 1 { return 32; };
    if close(cx_real(vec_get(r, 1)), f64_to_bits(0.0), 0.000001) != 1 { return 64; };
    if close(cx_real(vec_get(r, 2)), f64_to_bits(0.0), 0.000001) != 1 { return 128; };
    if close(cx_real(vec_get(r, 3)), f64_to_bits(0.0), 0.000001) != 1 { return 256; };
    return 0;
}

fn check_bell_range_window() -> i64 {
    let h: i64 = mps_init(2, 16);
    mps_h(h, 0);
    mps_cnot(h, 0, 1);

    let r: i64 = mps_statevector_range(h, 1, 2);
    mps_free(h);
    if r == 0 { return 512; };
    if vec_len(r) != 2 { return 1024; };
    if close(cx_real(vec_get(r, 0)), f64_to_bits(0.0), 0.000001) != 1 { return 2048; };
    if close(cx_imag(vec_get(r, 0)), f64_to_bits(0.0), 0.000001) != 1 { return 4096; };
    if close(cx_real(vec_get(r, 1)), f64_to_bits(0.0), 0.000001) != 1 { return 8192; };
    if close(cx_imag(vec_get(r, 1)), f64_to_bits(0.0), 0.000001) != 1 { return 16384; };
    return 0;
}

fn check_range_fail_closed() -> i64 {
    let h: i64 = mps_init(2, 16);
    if h == 0 { return 32768; };

    if mps_statevector_range_max_count() < 4 { mps_free(h); return 65536; };
    if mps_statevector_range(h, 0 - 1, 1) != 0 { mps_free(h); return 131072; };
    if mps_statevector_range(h, 0, mps_statevector_range_max_count() + 1) != 0 { mps_free(h); return 262144; };
    if mps_statevector_range(h, 4, 1) != 0 { mps_free(h); return 524288; };

    let empty: i64 = mps_statevector_range(h, 4, 0);
    mps_free(h);
    if empty == 0 { return 1048576; };
    if vec_len(empty) != 0 { return 2097152; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = mps_limitations();
    if str_index_of(s, "mps_statevector_range") < 0 { return 4194304; };
    if str_index_of(s, "caller-capped") < 0 { return 8388608; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_product_state_high_qubit_range();
    fails = fails + check_bell_range_window();
    fails = fails + check_range_fail_closed();
    fails = fails + check_limitations();
    return fails;
}
