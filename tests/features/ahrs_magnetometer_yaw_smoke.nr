// ROBO-12 Phase 1 -- AHRS magnetometer yaw correction smoke.
//
// Starts the Mahony filter at +90 degrees yaw while feeding zero gyro,
// level gravity, and a calibrated magnetic field pointing along world +X.
// Accel alone cannot observe yaw; the 9-DOF update must pull yaw toward
// the magnetic heading. Expected: rc=0.

import "stdlib/rods/ahrs.nr"
import "stdlib/rods/f64_buffer.nr"

fn abs_f64(x: f64) -> f64 {
    if x < 0.0 { return 0.0 - x; };
    return x;
}

fn main() -> i64 {
    let q: i64 = f64_buf_new(4);
    let gyro: i64 = f64_buf_new(3);
    let accel: i64 = f64_buf_new(3);
    let mag: i64 = f64_buf_new(3);
    let rpy: i64 = f64_buf_new(3);
    if q == 0 || gyro == 0 || accel == 0 || mag == 0 || rpy == 0 { return 1; };

    // q = yaw +90 degrees: [cos(pi/4), 0, 0, sin(pi/4)].
    f64_buf_set(q, 0, 0.7071067811865476);
    f64_buf_set(q, 1, 0.0);
    f64_buf_set(q, 2, 0.0);
    f64_buf_set(q, 3, 0.7071067811865476);

    f64_buf_set(gyro, 0, 0.0); f64_buf_set(gyro, 1, 0.0); f64_buf_set(gyro, 2, 0.0);
    f64_buf_set(accel, 0, 0.0); f64_buf_set(accel, 1, 0.0); f64_buf_set(accel, 2, 1.0);
    f64_buf_set(mag, 0, 1.0); f64_buf_set(mag, 1, 0.0); f64_buf_set(mag, 2, 0.0);

    let h: i64 = ahrs_new(f64_to_bits(2.0), f64_to_bits(0.0));
    if h == 0 { return 2; };
    ahrs_set_orientation(h, f64_buf_ptr(q));
    ahrs_get_euler(h, f64_buf_ptr(rpy));
    let initial_yaw: f64 = abs_f64(f64_buf_get(rpy, 2));
    if initial_yaw < 1.0 { ahrs_free(h); return 4; };

    let mut i: i64 = 0;
    while i < 160 {
        ahrs_update_mag(h, f64_buf_ptr(gyro), f64_buf_ptr(accel), f64_buf_ptr(mag), f64_to_bits(0.02));
        i = i + 1;
    };

    ahrs_get_euler(h, f64_buf_ptr(rpy));
    let final_yaw: f64 = abs_f64(f64_buf_get(rpy, 2));
    if !(final_yaw < 0.35) { ahrs_free(h); return 8; };
    if !(final_yaw < initial_yaw) { ahrs_free(h); return 16; };

    ahrs_free(h);
    f64_buf_free(q); f64_buf_free(gyro); f64_buf_free(accel); f64_buf_free(mag); f64_buf_free(rpy);
    return 0;
}
