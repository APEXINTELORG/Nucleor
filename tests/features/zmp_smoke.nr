// v0.8.184 stdlib/rods/zmp.nr first test coverage.
//
// Zero Moment Point (ZMP) tracking via cart-table + finite-
// horizon LQR. Bipedal-locomotion primitive. Pre-v0.8.184: zero
// coverage.
//
// Locks four lifecycle invariants on a 50-step trajectory at
// 0.01s, h=0.8m, with constant ZMP reference at x=0:
//
//   1. **Construction** returns valid handle.
//   2. **Initial state retained**: with c0=0, cdot0=0, cddot0=0
//      and zmp_ref==0 throughout, com[0] == 0.
//   3. **Solve returns success** for valid inputs.
//   4. **CoM stays bounded** under zero-reference tracking — no
//      runaway.
//
// Expected: rc=0.

import "stdlib/rods/zmp.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_handle() -> i64 {
    let h: i64 = zmp_new(f64_to_bits(0.8), f64_to_bits(0.01), 50);
    if h == 0 { return 1; };
    zmp_free(h);
    return 0;
}

fn check_initial_state_retained() -> i64 {
    let h: i64 = zmp_new(f64_to_bits(0.8), f64_to_bits(0.01), 50);
    let mut k: i64 = 0;
    while k < 50 {
        zmp_set_zmp_ref(h, k, f64_to_bits(0.0));
        k = k + 1;
    };
    zmp_set_initial_state(h, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let r: i64 = zmp_solve(h, f64_to_bits(1e-6));
    if r != 1 { zmp_free(h); return 2; };
    let c0: i64 = zmp_com(h, 0);
    if close(c0, f64_to_bits(0.0), 1e-6) != 1 { zmp_free(h); return 4; };
    zmp_free(h);
    return 0;
}

fn check_bounded_under_zero_ref() -> i64 {
    let h: i64 = zmp_new(f64_to_bits(0.8), f64_to_bits(0.01), 50);
    let mut k: i64 = 0;
    while k < 50 {
        zmp_set_zmp_ref(h, k, f64_to_bits(0.0));
        k = k + 1;
    };
    zmp_set_initial_state(h, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    zmp_solve(h, f64_to_bits(1e-6));
    // CoM should stay near 0 since reference is 0 and initial state is 0.
    let mut i: i64 = 0;
    while i <= 50 {
        let c_bits: i64 = zmp_com(h, i);
        let c: f64 = f64_from_bits(c_bits);
        let abs_c: f64 = if c < 0.0 { 0.0 - c } else { c };
        if abs_c > 0.1 { zmp_free(h); return 8; };
        i = i + 1;
    };
    zmp_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_handle();
    fails = fails + check_initial_state_retained();
    fails = fails + check_bounded_under_zero_ref();
    return fails;
}
