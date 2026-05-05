// v0.8.183 stdlib/rods/thermo.nr first test coverage.
//
// Heat-transfer + thermodynamics primitives. Pre-v0.8.183:
// zero coverage on the standalone thermo rod.
//
// Locks four textbook physics invariants:
//
//   1. **Carnot efficiency**: 1 - Tc/Th. Th=400K, Tc=300K → 0.25.
//   2. **Carnot edge case**: Tc==Th (no temperature gradient) → 0.
//   3. **Ideal gas P solve**: PV=nRT solved for P given V, n, T.
//      n=1mol, V=22.4L=0.0224m³, T=273K → P ≈ 101325 Pa (STP).
//   4. **Stefan-Boltzmann**: P = ε·σ·A·T⁴ at T=1, ε=1, A=1
//      → returns σ ≈ 5.67e-8.
//
// Expected: rc=0.

import "stdlib/rods/thermo.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_carnot_400_300() -> i64 {
    let r: i64 = thermo_carnot(f64_to_bits(400.0), f64_to_bits(300.0));
    if close(r, f64_to_bits(0.25), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_carnot_no_gradient() -> i64 {
    let r: i64 = thermo_carnot(f64_to_bits(300.0), f64_to_bits(300.0));
    if close(r, f64_to_bits(0.0), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_ideal_gas_stp() -> i64 {
    // PV = nRT; n=1, V=0.0224 m³, T=273K → P ≈ 1.0133e5 Pa (atmospheric)
    // P==0 means "solve for P"
    let p: i64 = thermo_ideal_gas(
        f64_to_bits(0.0),     // P (unknown)
        f64_to_bits(0.0224),  // V
        f64_to_bits(1.0),     // n
        f64_to_bits(273.0)    // T
    );
    let pf: f64 = f64_from_bits(p);
    // Expected ~ 1.013e5; allow ±2% tolerance for STP rounding
    if pf < 99000.0 { return 4; };
    if pf > 105000.0 { return 8; };
    return 0;
}

fn check_radiation_stefan_boltzmann() -> i64 {
    // P = ε·σ·A·T⁴; ε=1, A=1, T=1 → P = σ = 5.6703744e-8
    let p: i64 = thermo_radiation(f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));
    if close(p, f64_to_bits(5.670374419e-8), 1e-12) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_carnot_400_300();
    fails = fails + check_carnot_no_gradient();
    fails = fails + check_ideal_gas_stp();
    fails = fails + check_radiation_stefan_boltzmann();
    return fails;
}
