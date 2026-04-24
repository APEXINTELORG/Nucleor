// rods/ahrs — Attitude & Heading Reference System via the
// Mahony quaternion complementary filter (Mahony, Hamel & Pflimlin
// 2008).
//
// Maintains a unit quaternion `q` (body → world rotation) from
// IMU readings:
//   - Gyroscope: angular velocity ω (rad/s, body frame)
//   - Accelerometer: gravity vector a (body frame; magnitude
//     normalized internally)
//
// Each tick:
//   - Predict gravity in body frame from current q.
//   - Compute error = predicted × measured (cross product).
//   - Apply PI correction to ω (Kp instantaneous, Ki accumulates
//     as a gyro-bias estimate).
//   - Integrate corrected ω into q via q̇ = 0.5 · q · (0, ω); step.
//   - Normalize q.
//
// With Kp = 1.0, Ki = 0.0 (defaults), the filter reduces to a
// pure complementary filter. Kp ≈ 1.0 is appropriate for typical
// IMU noise; raise it for noisier accels, lower it for cleaner
// ones. Ki ≈ 0.05 is typical when gyro bias drift is significant.
//
// Workflow:
//
//   import "stdlib/rods/ahrs.nr"
//
//   let h = ahrs_new(Kp_b, Ki_b);
//   // optional initial orientation:
//   ahrs_set_orientation(h, q_init_ptr);
//
//   for tick {
//       ahrs_update(h, gyro_ptr, accel_ptr, dt_b);
//       ahrs_get_orientation(h, q_out_ptr);
//       // or roll/pitch/yaw (radians):
//       ahrs_get_euler(h, rpy_out_ptr);
//   }
//
//   ahrs_free(h);
//
// **Limitations** (magnetometer fusion / Madgwick variant land
// in v0.6 if needed):
// - Yaw is unobservable from accel (gravity is yaw-invariant).
//   Yaw drifts at the gyro bias rate; add a magnetometer
//   correction for absolute heading.
// - Assumes near-zero linear acceleration. Under high-g maneuvers
//   the accel reads g + a_motion and the filter is biased — drop
//   the accel correction temporarily when |a| ≫ |g|.
//
// See `stdlib/runtime/ahrs_rt.c`.
#cfile "../runtime/ahrs_rt.c"

extern fn nuc_ahrs_new(Kp_b: i64, Ki_b: i64) -> i64;
extern fn nuc_ahrs_set_gains(h: i64, Kp_b: i64, Ki_b: i64);
extern fn nuc_ahrs_set_orientation(h: i64, q_ptr: i64);
extern fn nuc_ahrs_get_orientation(h: i64, q_ptr: i64);
extern fn nuc_ahrs_get_euler(h: i64, rpy_ptr: i64);
extern fn nuc_ahrs_update(h: i64, gyro_ptr: i64, accel_ptr: i64, dt_b: i64);
extern fn nuc_ahrs_get_bias(h: i64, bias_ptr: i64);
extern fn nuc_ahrs_free(h: i64);

// Create an AHRS filter. Kp = proportional accel→tilt correction
// gain (typical 1.0); Ki = integral gyro-bias estimation gain
// (typical 0.0–0.1; 0.0 disables bias estimation).
fn ahrs_new(Kp_b: i64, Ki_b: i64) -> i64 { return nuc_ahrs_new(Kp_b, Ki_b); }

fn ahrs_set_gains(h: i64, Kp_b: i64, Ki_b: i64) {
    nuc_ahrs_set_gains(h, Kp_b, Ki_b);
}

// Set the current quaternion estimate. `q_ptr` is double[4]
// (qw, qx, qy, qz). Normalized internally.
fn ahrs_set_orientation(h: i64, q_ptr: i64) { nuc_ahrs_set_orientation(h, q_ptr); }

// Read out the current quaternion estimate.
fn ahrs_get_orientation(h: i64, q_ptr: i64) { nuc_ahrs_get_orientation(h, q_ptr); }

// Read the current orientation as ZYX-Euler angles
// (roll, pitch, yaw) in radians.
fn ahrs_get_euler(h: i64, rpy_ptr: i64) { nuc_ahrs_get_euler(h, rpy_ptr); }

// One IMU step. `gyro_ptr` and `accel_ptr` are double[3] in body
// frame. Pass 0 for `accel_ptr` to skip the accel correction
// (useful during high-acceleration maneuvers when the accel reads
// g + a_motion and would bias the filter).
fn ahrs_update(h: i64, gyro_ptr: i64, accel_ptr: i64, dt_b: i64) {
    nuc_ahrs_update(h, gyro_ptr, accel_ptr, dt_b);
}

// Read the estimated gyro bias (3 doubles) accumulated by the Ki
// term. Useful for sensor diagnostics.
fn ahrs_get_bias(h: i64, bias_ptr: i64) { nuc_ahrs_get_bias(h, bias_ptr); }

fn ahrs_free(h: i64) { nuc_ahrs_free(h); }
