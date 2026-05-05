// v0.8.214 stdlib/rods/mps.nr first test coverage.
//
// Matrix Product States — efficient quantum simulation that
// scales to 20-50 qubits via SVD-truncated bond contraction.
// Pre-v0.8.214: zero coverage on the standalone rod (used in
// the Carleman-Vlasov experiment but no fixture).
//
// Gate type IDs (from runtime): 0=H, 1=CNOT, 2=X, 3=Z, 4=RZ.
//
// Locks four textbook quantum-state invariants:
//
//   1. **Initial |0⟩ has ⟨Z⟩ = +1** — Z eigenvalue on |0⟩.
//   2. **X gate flips ⟨Z⟩ to -1** — X|0⟩ = |1⟩, ⟨Z⟩(|1⟩) = -1.
//   3. **HH = I** — applying H twice returns to |0⟩,
//      ⟨Z⟩ = +1 again.
//   4. **Fresh MPS has max_bond == 1** — mps_max_bond returns
//      the CURRENT max bond dimension across the chain (not the
//      cap). At init the state is product |00...⟩ so all bonds = 1.
//
// Expected: rc=0.

import "stdlib/rods/mps.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_initial_state_z() -> i64 {
    let h: i64 = mps_init(2, 16);
    let z: i64 = mps_expect_z(h, 0);
    mps_free(h);
    if close(z, f64_to_bits(1.0), 1e-6) != 1 { return 1; };
    return 0;
}

fn check_x_flips_z() -> i64 {
    let h: i64 = mps_init(2, 16);
    mps_gate(h, 2, 0, 0, 0);  // X on qubit 0
    let z: i64 = mps_expect_z(h, 0);
    mps_free(h);
    if close(z, f64_to_bits(0.0 - 1.0), 1e-6) != 1 { return 2; };
    return 0;
}

fn check_hh_identity() -> i64 {
    let h: i64 = mps_init(2, 16);
    mps_gate(h, 0, 0, 0, 0);  // H on qubit 0
    mps_gate(h, 0, 0, 0, 0);  // H again
    let z: i64 = mps_expect_z(h, 0);
    mps_free(h);
    if close(z, f64_to_bits(1.0), 1e-6) != 1 { return 4; };
    return 0;
}

fn check_max_bond_at_init() -> i64 {
    // Fresh state |0000⟩ is a product state; all bonds = 1.
    let h: i64 = mps_init(4, 16);
    let mb: i64 = mps_max_bond(h);
    mps_free(h);
    if mb != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_initial_state_z();
    fails = fails + check_x_flips_z();
    fails = fails + check_hh_identity();
    fails = fails + check_max_bond_at_init();
    return fails;
}
