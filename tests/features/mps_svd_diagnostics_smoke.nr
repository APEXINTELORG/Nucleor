// v0853 QM-5 - MPS SVD convergence and clamp diagnostics.
//
// Locks the public diagnostic surface for the Jacobi SVD used by adjacent
// two-qubit MPS gates. The simple Bell circuit should converge, require at
// least one recorded sweep, keep nonconvergence totals at zero, and avoid
// negative-eigenvalue clamps.

import "stdlib/rods/mps.nr"

fn check_initial_diagnostics() -> i64 {
    let h: i64 = mps_init(2, 16);
    if mps_last_svd_converged(h) != 1 { mps_free(h); return 1; };
    if mps_last_svd_sweeps(h) != 0 { mps_free(h); return 2; };
    if f64_from_bits(mps_last_svd_off_norm(h)) != 0.0 { mps_free(h); return 4; };
    if mps_last_svd_negative_clamps(h) != 0 { mps_free(h); return 8; };
    if mps_total_svd_nonconverged(h) != 0 { mps_free(h); return 16; };
    if mps_total_svd_negative_clamps(h) != 0 { mps_free(h); return 32; };
    mps_free(h);
    return 0;
}

fn check_bell_svd_diagnostics() -> i64 {
    let h: i64 = mps_init(2, 16);
    mps_h(h, 0);

    if mps_last_svd_sweeps(h) != 0 { mps_free(h); return 64; };

    mps_cnot(h, 0, 1);
    let sweeps: i64 = mps_last_svd_sweeps(h);
    let off: f64 = f64_from_bits(mps_last_svd_off_norm(h));

    if mps_last_svd_converged(h) != 1 { mps_free(h); return 128; };
    if sweeps <= 0 { mps_free(h); return 256; };
    if sweeps > 100 { mps_free(h); return 512; };
    if off < 0.0 { mps_free(h); return 1024; };
    if off > 1e-20 { mps_free(h); return 2048; };
    if mps_last_svd_negative_clamps(h) != 0 { mps_free(h); return 4096; };
    if mps_total_svd_nonconverged(h) != 0 { mps_free(h); return 8192; };
    if mps_total_svd_negative_clamps(h) != 0 { mps_free(h); return 16384; };

    mps_free(h);
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = mps_limitations();
    if str_index_of(s, "QM-5") < 0 { return 32768; };
    if str_index_of(s, "mps_last_svd_converged") < 0 { return 65536; };
    if str_index_of(s, "mps_total_svd_nonconverged") < 0 { return 131072; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_initial_diagnostics();
    fails = fails + check_bell_svd_diagnostics();
    fails = fails + check_limitations();
    return fails;
}
