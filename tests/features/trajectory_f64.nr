// stdlib/rods/trajectory — `*_f64` ergonomic wrappers.
//
// v0.4.264: quintic + trapezoidal + s-curve motion profiles
// now have f64-typed constructors and evaluators. Adopter
// writes `quintic_new_f64(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0)`
// instead of seven `f64_to_bits(...)` wraps.
//
// EXPECT: build success, runtime exit 0, output "OK trajectory_f64".

import "stdlib/rods/trajectory.nr"

fn main() -> i32 {
    // === Quintic: rest-to-rest q 0→1 over T=2.0s ===
    let q: i64 = quintic_new_f64(2.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0);
    if q == 0 { print("FAIL quintic_new_f64"); return 1; };

    // Duration round-trip.
    let dur: f64 = quintic_duration_f64(q);
    if (dur as i32) != 2 { print("FAIL quintic_duration_f64"); return 1; };

    // Boundary positions: q(0)=0, q(T)=1.
    let p0: f64 = quintic_pos_at_f64(q, 0.0);
    if (p0 as i32) != 0 { print("FAIL quintic_pos_at_f64(0)"); return 1; };
    let pT: f64 = quintic_pos_at_f64(q, 2.0);
    if (pT as i32) != 1 { print("FAIL quintic_pos_at_f64(T)"); return 1; };

    // Boundary velocities: v(0)=0, v(T)=0.
    let v0: f64 = quintic_vel_at_f64(q, 0.0);
    if (v0 as i32) != 0 { print("FAIL quintic_vel_at_f64(0)"); return 1; };
    let vT: f64 = quintic_vel_at_f64(q, 2.0);
    if (vT as i32) != 0 { print("FAIL quintic_vel_at_f64(T)"); return 1; };

    // Boundary accelerations: a(0)=0, a(T)=0.
    let a0: f64 = quintic_acc_at_f64(q, 0.0);
    if (a0 as i32) != 0 { print("FAIL quintic_acc_at_f64(0)"); return 1; };
    let aT: f64 = quintic_acc_at_f64(q, 2.0);
    if (aT as i32) != 0 { print("FAIL quintic_acc_at_f64(T)"); return 1; };

    quintic_free(q);

    // === Trapezoidal: q 0→1, vmax=2, amax=4 ===
    let tp: i64 = trapezoid_new_f64(0.0, 1.0, 2.0, 4.0);
    if tp == 0 { print("FAIL trapezoid_new_f64"); return 1; };

    let tdur: f64 = trapezoid_duration_f64(tp);
    if !(tdur > 0.0) { print("FAIL trapezoid_duration_f64"); return 1; };

    let pkv: f64 = trapezoid_peak_v_f64(tp);
    if !(pkv > 0.0) { print("FAIL trapezoid_peak_v_f64"); return 1; };

    // Boundary check: pos(0) ≈ 0, pos(T) ≈ 1.
    let tp0: f64 = trapezoid_pos_at_f64(tp, 0.0);
    if (tp0 as i32) != 0 { print("FAIL trapezoid_pos_at_f64(0)"); return 1; };

    // Velocity at start should be 0.
    let tv0: f64 = trapezoid_vel_at_f64(tp, 0.0);
    if (tv0 as i32) != 0 { print("FAIL trapezoid_vel_at_f64(0)"); return 1; };

    trapezoid_free(tp);

    // === S-curve: q 0→1, vmax=2, amax=4, jmax=20 ===
    // v0.8.261: trajectory rod's scurve_*_f64 renamed to
    // traj_scurve_*_f64 to break collision with scurve.nr.
    let sc: i64 = traj_scurve_new_f64(0.0, 1.0, 2.0, 4.0, 20.0);
    if sc == 0 { print("FAIL traj_scurve_new_f64"); return 1; };

    let sdur: f64 = traj_scurve_duration_f64(sc);
    if !(sdur > 0.0) { print("FAIL traj_scurve_duration_f64"); return 1; };

    let spv: f64 = traj_scurve_peak_v_f64(sc);
    if !(spv > 0.0) { print("FAIL traj_scurve_peak_v_f64"); return 1; };

    let spa: f64 = traj_scurve_peak_a_f64(sc);
    if !(spa > 0.0) { print("FAIL traj_scurve_peak_a_f64"); return 1; };

    let sp0: f64 = traj_scurve_pos_at_f64(sc, 0.0);
    if (sp0 as i32) != 0 { print("FAIL traj_scurve_pos_at_f64(0)"); return 1; };

    traj_scurve_free(sc);

    print("OK trajectory_f64");
    0
}
