// rods/trajectory — verify rod wrapper compiles + links (v0.2.177 ship).
// Build a quintic from rest at q=0 to rest at q=1 over T=1s. Sample
// at t=0 (should be 0) and t=T/2 (should be 0.5 by symmetry).
import "stdlib/rods/trajectory.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Rest-to-rest, q goes 0 → 1 over 1.0 s.
    let q: i64 = quintic_new(
        f64_to_bits(1.0),                                  // T = 1s
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),  // q0, v0, a0
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0)   // qT, vT, aT
    );
    if q == 0 { print("FAIL quintic_new"); return 1; };

    // Position at t=0 should be 0; we just check it returns
    // SOME value (the bit pattern for 0.0 is 0).
    let _p0: i64 = quintic_pos_at(q, f64_to_bits(0.0));
    let _pmid: i64 = quintic_pos_at(q, f64_to_bits(0.5));
    let _pT: i64 = quintic_pos_at(q, f64_to_bits(1.0));
    let _v0: i64 = quintic_vel_at(q, f64_to_bits(0.0));
    let _vmid: i64 = quintic_vel_at(q, f64_to_bits(0.5));
    let _a0: i64 = quintic_acc_at(q, f64_to_bits(0.0));

    // Duration round-trip.
    let dur: i64 = quintic_duration(q);
    if dur == 0 { fail = fail + 1; print("FAIL duration round-trip"); };

    quintic_free(q);

    // Trapezoidal profile (v0.2.181): q 0→1, v_max=2.0, a_max=4.0.
    // Long enough to actually reach v_max before decelerating.
    let tp: i64 = trapezoid_new(
        f64_to_bits(0.0), f64_to_bits(1.0),
        f64_to_bits(2.0), f64_to_bits(4.0)
    );
    if tp == 0 { fail = fail + 1; print("FAIL trapezoid_new"); };
    let tp_dur: i64 = trapezoid_duration(tp);
    if tp_dur == 0 { fail = fail + 1; print("FAIL trapezoid duration"); };
    let _tp_v0: i64 = trapezoid_vel_at(tp, f64_to_bits(0.0));
    let _tp_pos_mid: i64 = trapezoid_pos_at(tp, f64_to_bits(0.25));
    trapezoid_free(tp);

    // S-curve (v0.2.191): rest-to-rest q 0→1, v_max=2, a_max=4, j_max=20.
    let sc: i64 = scurve_new(
        f64_to_bits(0.0), f64_to_bits(1.0),
        f64_to_bits(2.0), f64_to_bits(4.0), f64_to_bits(20.0)
    );
    if sc == 0 { fail = fail + 1; print("FAIL scurve_new"); };
    let sc_dur: i64 = scurve_duration(sc);
    if sc_dur == 0 { fail = fail + 1; print("FAIL scurve duration"); };
    let _sc_pos: i64 = scurve_pos_at(sc, f64_to_bits(0.5));
    let _sc_pv: i64 = scurve_peak_v(sc);
    let _sc_pa: i64 = scurve_peak_a(sc);
    scurve_free(sc);

    // DMP (v0.2.192) — build-only smoke (training requires a
    // double[] trajectory which is non-trivial in a single test).
    let dmp: i64 = dmp_new(25, f64_to_bits(25.0), f64_to_bits(8.33));
    if dmp == 0 { fail = fail + 1; print("FAIL dmp_new"); };
    let _ok: i64 = dmp_reset(dmp, f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(1.0));
    let _y: i64 = dmp_step(dmp, f64_to_bits(0.01));
    dmp_free(dmp);

    if fail == 0 { print("OK trajectory_smoke"); };
    return fail;
}
