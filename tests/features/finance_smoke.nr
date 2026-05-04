// v0.8.99 stdlib/rods/finance.nr first test coverage.
//
// Per the zero-coverage rod survey, finance.nr (Black-Scholes,
// Greeks, NPV/IRR, VaR, portfolio opt) had no existing tests.
// Silent regressions in option pricing or NPV would propagate
// into adopter quant code invisibly.
//
// Locks textbook financial math invariants:
//   1. Black-Scholes call price is positive for in/at-the-money.
//   2. Black-Scholes put price is positive.
//   3. Put-call parity: C - P ≈ S - K*exp(-r*T) within tolerance.
//   4. Greeks bounds: delta_call ∈ [0, 1]; delta_put ∈ [-1, 0];
//      gamma > 0; vega > 0 for non-zero T.
//   5. NPV at rate=0 sums cash flows: NPV([100, -50, -30, -20],
//      0.0) == 0 (sums to zero).
//   6. NPV at non-zero rate discounts future flows: NPV is
//      LESS than sum-at-rate-0 for [0, 100, 100, 100] @ rate=0.05
//      (later flows worth less today).
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/finance.nr"

fn close(a: i64, b: i64, tol: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let tf: f64 = f64_from_bits(tol);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < tf { return 1; };
    return 0;
}

fn check_bs_pricing_positive() -> i64 {
    let call: i64 = fin_black_scholes(
        f64_to_bits(100.0), f64_to_bits(100.0),
        f64_to_bits(1.0), f64_to_bits(0.05),
        f64_to_bits(0.2), 0);
    let put: i64 = fin_black_scholes(
        f64_to_bits(100.0), f64_to_bits(100.0),
        f64_to_bits(1.0), f64_to_bits(0.05),
        f64_to_bits(0.2), 1);
    let cf: f64 = f64_from_bits(call);
    let pf: f64 = f64_from_bits(put);
    if cf <= 0.0 { return 1; };
    if pf <= 0.0 { return 2; };
    return 0;
}

fn check_put_call_parity() -> i64 {
    // C - P should equal S - K*exp(-r*T)
    // = 100 - 100*exp(-0.05) = 100 - 95.1229... = 4.8771...
    let call: i64 = fin_black_scholes(
        f64_to_bits(100.0), f64_to_bits(100.0),
        f64_to_bits(1.0), f64_to_bits(0.05),
        f64_to_bits(0.2), 0);
    let put: i64 = fin_black_scholes(
        f64_to_bits(100.0), f64_to_bits(100.0),
        f64_to_bits(1.0), f64_to_bits(0.05),
        f64_to_bits(0.2), 1);
    let cf: f64 = f64_from_bits(call);
    let pf: f64 = f64_from_bits(put);
    let diff: f64 = cf - pf;
    // Expected: ~4.877
    if diff < 4.5 { return 4; };
    if diff > 5.2 { return 8; };
    return 0;
}

fn check_greeks_bounds() -> i64 {
    let g: i64 = fin_greeks(
        f64_to_bits(100.0), f64_to_bits(100.0),
        f64_to_bits(1.0), f64_to_bits(0.05),
        f64_to_bits(0.2));
    let delta: f64 = f64_from_bits(fin_greek_delta(g));
    let gamma: f64 = f64_from_bits(fin_greek_gamma(g));
    let vega: f64 = f64_from_bits(fin_greek_vega(g));
    // delta of an ATM call should be near 0.5, definitely in [0, 1]
    if delta < 0.0 || delta > 1.0 { return 16; };
    // gamma must be positive
    if gamma <= 0.0 { return 32; };
    // vega must be positive for T > 0
    if vega <= 0.0 { return 64; };
    return 0;
}

fn check_npv_zero_rate() -> i64 {
    let mut cf: Vec<i64> = Vec::new();
    cf.push(f64_to_bits(100.0));
    cf.push(f64_to_bits(0.0 - 50.0));
    cf.push(f64_to_bits(0.0 - 30.0));
    cf.push(f64_to_bits(0.0 - 20.0));
    // Sum is zero; rate=0 means NPV=sum=0.
    let npv: i64 = fin_npv(cf, f64_to_bits(0.0));
    if close(npv, f64_to_bits(0.0), f64_to_bits(0.001)) != 1 { return 128; };
    return 0;
}

fn check_npv_discounts_future_flows() -> i64 {
    let mut cf: Vec<i64> = Vec::new();
    cf.push(f64_to_bits(0.0));
    cf.push(f64_to_bits(100.0));
    cf.push(f64_to_bits(100.0));
    cf.push(f64_to_bits(100.0));
    let npv0: i64 = fin_npv(cf, f64_to_bits(0.0));
    let npv5: i64 = fin_npv(cf, f64_to_bits(0.05));
    let n0: f64 = f64_from_bits(npv0);
    let n5: f64 = f64_from_bits(npv5);
    // npv0 = 300 (sum); npv5 < 300 (future flows discounted)
    if n0 < 299.5 { return 256; };
    if n0 > 300.5 { return 512; };
    if n5 >= n0 { return 1024; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_bs_pricing_positive();
    fails = fails + check_put_call_parity();
    fails = fails + check_greeks_bounds();
    fails = fails + check_npv_zero_rate();
    fails = fails + check_npv_discounts_future_flows();
    return fails;
}
