// QM-6 v0842 - MPS streaming-range fold smoke.
//
// Locks the bounded fold helpers in stdlib/rods/mps.nr against a
// 2-qubit Bell state and a 3-qubit GHZ state without materializing
// per-state Vec<complex>:
//   - mps_statevector_range_max_fold_count() exceeds the
//     materializing cap (mps_statevector_range_max_count())
//   - mps_statevector_range_prob_sum / nonzero_count match the
//     known sparsity / probability mass of |Bell> and |GHZ>
//   - empty range (count=0) folds to 0 / 0 without erroring
//   - out-of-range start, negative inputs, and over-cap count
//     return _mf2i(-1.0) / -1 sentinels
//
// Expected: rc=0.

import "stdlib/rods/mps.nr"
import "stdlib/rods/strings.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_fold_cap_relationship() -> i64 {
    let mat_cap: i64 = mps_statevector_range_max_count();
    let fold_cap: i64 = mps_statevector_range_max_fold_count();
    if mat_cap < 1 { return 1; };
    if fold_cap < 1 { return 2; };
    if fold_cap <= mat_cap { return 3; };
    return 0;
}

fn check_bell_full_range_fold() -> i64 {
    let h: i64 = mps_init(2, 16);
    if h == 0 { return 10; };
    mps_h(h, 0);
    mps_cnot(h, 0, 1);

    // Full 4-state range covers entire 2-qubit basis.
    let prob_full: i64 = mps_statevector_range_prob_sum(h, 0, 4);
    let nz_full: i64 = mps_statevector_range_nonzero_count(h, 0, 4);
    mps_free(h);

    if close(prob_full, f64_to_bits(1.0), 1e-6) != 1 { return 11; };
    if nz_full != 2 { return 12; };
    return 0;
}

fn check_bell_subrange_folds() -> i64 {
    let h: i64 = mps_init(2, 16);
    if h == 0 { return 20; };
    mps_h(h, 0);
    mps_cnot(h, 0, 1);

    // [0..2): basis |00> only -> prob 0.5, nonzero 1
    let p_lo: i64 = mps_statevector_range_prob_sum(h, 0, 2);
    let nz_lo: i64 = mps_statevector_range_nonzero_count(h, 0, 2);

    // [1..3): basis |01> + |10> -> prob 0.0, nonzero 0
    let p_mid: i64 = mps_statevector_range_prob_sum(h, 1, 2);
    let nz_mid: i64 = mps_statevector_range_nonzero_count(h, 1, 2);

    // [2..4): basis |10> + |11> -> prob 0.5, nonzero 1
    let p_hi: i64 = mps_statevector_range_prob_sum(h, 2, 2);
    let nz_hi: i64 = mps_statevector_range_nonzero_count(h, 2, 2);

    // Single-state windows.
    let p_00: i64 = mps_statevector_range_prob_sum(h, 0, 1);
    let p_11: i64 = mps_statevector_range_prob_sum(h, 3, 1);
    let p_01: i64 = mps_statevector_range_prob_sum(h, 1, 1);
    mps_free(h);

    if close(p_lo, f64_to_bits(0.5), 1e-6) != 1 { return 21; };
    if nz_lo != 1 { return 22; };
    if close(p_mid, f64_to_bits(0.0), 1e-6) != 1 { return 23; };
    if nz_mid != 0 { return 24; };
    if close(p_hi, f64_to_bits(0.5), 1e-6) != 1 { return 25; };
    if nz_hi != 1 { return 26; };

    if close(p_00, f64_to_bits(0.5), 1e-6) != 1 { return 27; };
    if close(p_11, f64_to_bits(0.5), 1e-6) != 1 { return 28; };
    if close(p_01, f64_to_bits(0.0), 1e-6) != 1 { return 29; };
    return 0;
}

fn check_ghz_full_and_partial_folds() -> i64 {
    // 3-qubit GHZ via H + CNOT(0,1) + CNOT(1,2). Expect amplitudes
    // of 1/sqrt(2) on |000> (basis 0) and |111> (basis 7); zeros
    // elsewhere. Total prob = 1, nonzero count = 2 over the full
    // 8-state range.
    let h: i64 = mps_init(3, 16);
    if h == 0 { return 40; };
    mps_h(h, 0);
    mps_cnot(h, 0, 1);
    mps_cnot(h, 1, 2);

    let p_all: i64 = mps_statevector_range_prob_sum(h, 0, 8);
    let nz_all: i64 = mps_statevector_range_nonzero_count(h, 0, 8);

    // [0..4): contains only |000>; expected prob 0.5, nonzero 1
    let p_lower: i64 = mps_statevector_range_prob_sum(h, 0, 4);
    let nz_lower: i64 = mps_statevector_range_nonzero_count(h, 0, 4);

    // [4..8): contains only |111>; expected prob 0.5, nonzero 1
    let p_upper: i64 = mps_statevector_range_prob_sum(h, 4, 4);
    let nz_upper: i64 = mps_statevector_range_nonzero_count(h, 4, 4);

    // [1..7): the entire interior gap; expected prob 0, nonzero 0
    let p_gap: i64 = mps_statevector_range_prob_sum(h, 1, 6);
    let nz_gap: i64 = mps_statevector_range_nonzero_count(h, 1, 6);
    mps_free(h);

    if close(p_all, f64_to_bits(1.0), 1e-6) != 1 { return 41; };
    if nz_all != 2 { return 42; };
    if close(p_lower, f64_to_bits(0.5), 1e-6) != 1 { return 43; };
    if nz_lower != 1 { return 44; };
    if close(p_upper, f64_to_bits(0.5), 1e-6) != 1 { return 45; };
    if nz_upper != 1 { return 46; };
    if close(p_gap, f64_to_bits(0.0), 1e-6) != 1 { return 47; };
    if nz_gap != 0 { return 48; };
    return 0;
}

fn check_empty_range() -> i64 {
    let h: i64 = mps_init(2, 16);
    if h == 0 { return 60; };
    mps_h(h, 0);
    mps_cnot(h, 0, 1);

    let p0: i64 = mps_statevector_range_prob_sum(h, 0, 0);
    let nz0: i64 = mps_statevector_range_nonzero_count(h, 0, 0);
    let p_at_end: i64 = mps_statevector_range_prob_sum(h, 4, 0);
    let nz_at_end: i64 = mps_statevector_range_nonzero_count(h, 4, 0);
    mps_free(h);

    if close(p0, f64_to_bits(0.0), 1e-6) != 1 { return 61; };
    if nz0 != 0 { return 62; };
    if close(p_at_end, f64_to_bits(0.0), 1e-6) != 1 { return 63; };
    if nz_at_end != 0 { return 64; };
    return 0;
}

fn check_invalid_inputs_return_sentinels() -> i64 {
    let h: i64 = mps_init(2, 16);
    if h == 0 { return 70; };
    mps_h(h, 0);
    mps_cnot(h, 0, 1);

    let neg_eps: f64 = 0.0 - 0.5;

    // Invalid handle.
    let p_h0: i64 = mps_statevector_range_prob_sum(0, 0, 1);
    let nz_h0: i64 = mps_statevector_range_nonzero_count(0, 0, 1);

    // Negative start_basis / count.
    let p_ns: i64 = mps_statevector_range_prob_sum(h, 0 - 1, 1);
    let nz_ns: i64 = mps_statevector_range_nonzero_count(h, 0 - 1, 1);
    let p_nc: i64 = mps_statevector_range_prob_sum(h, 0, 0 - 1);
    let nz_nc: i64 = mps_statevector_range_nonzero_count(h, 0, 0 - 1);

    // start beyond total: 2^2 = 4 basis states; start=5 is past total.
    let p_start_over: i64 = mps_statevector_range_prob_sum(h, 5, 1);
    let nz_start_over: i64 = mps_statevector_range_nonzero_count(h, 5, 1);

    // start + count beyond total.
    let p_overflow: i64 = mps_statevector_range_prob_sum(h, 3, 5);
    let nz_overflow: i64 = mps_statevector_range_nonzero_count(h, 3, 5);

    // Over the fold cap (count > max_fold_count).
    let cap: i64 = mps_statevector_range_max_fold_count();
    let p_cap: i64 = mps_statevector_range_prob_sum(h, 0, cap + 1);
    let nz_cap: i64 = mps_statevector_range_nonzero_count(h, 0, cap + 1);

    mps_free(h);

    if f64_lt(f64_from_bits(p_h0), neg_eps) != 1 { return 71; };
    if nz_h0 != 0 - 1 { return 72; };
    if f64_lt(f64_from_bits(p_ns), neg_eps) != 1 { return 73; };
    if nz_ns != 0 - 1 { return 74; };
    if f64_lt(f64_from_bits(p_nc), neg_eps) != 1 { return 75; };
    if nz_nc != 0 - 1 { return 76; };
    if f64_lt(f64_from_bits(p_start_over), neg_eps) != 1 { return 77; };
    if nz_start_over != 0 - 1 { return 78; };
    if f64_lt(f64_from_bits(p_overflow), neg_eps) != 1 { return 79; };
    if nz_overflow != 0 - 1 { return 80; };
    if f64_lt(f64_from_bits(p_cap), neg_eps) != 1 { return 81; };
    if nz_cap != 0 - 1 { return 82; };
    return 0;
}

fn check_limitations_text() -> i64 {
    let s: str = mps_limitations();
    if str_index_of(s, "QM-6") < 0 { return 90; };
    if str_index_of(s, "STREAMING-RANGE") < 0 { return 91; };
    if str_index_of(s, "mps_statevector_range_prob_sum") < 0 { return 92; };
    if str_index_of(s, "mps_statevector_range_nonzero_count") < 0 { return 93; };
    if str_index_of(s, "mps_statevector_range_max_fold_count") < 0 { return 94; };
    if str_index_of(s, "callback") < 0 { return 95; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_fold_cap_relationship();
    fails = fails + check_bell_full_range_fold();
    fails = fails + check_bell_subrange_folds();
    fails = fails + check_ghz_full_and_partial_folds();
    fails = fails + check_empty_range();
    fails = fails + check_invalid_inputs_return_sentinels();
    fails = fails + check_limitations_text();
    return fails;
}
