// v0.8.213 stdlib/rods/kinematics.nr first test coverage.
//
// 3-D math primitives for robotics — Vec3, Quaternion, Pose
// (position + orientation). Pre-v0.8.213: zero coverage on the
// standalone rod (sister to `quat.nr` which is `[4]double` form).
//
// Locks four textbook 3-D-math invariants:
//
//   1. **Vec3 component round-trip** — vec3_f64(1,2,3) → x=1, y=2, z=3.
//   2. **Cross product orthogonality** — x̂ × ŷ = ẑ
//      (1,0,0) × (0,1,0) = (0,0,1).
//   3. **Quaternion identity rotation** — quat_identity rotates
//      any vector to itself.
//   4. **Pose-identity is identity** — pose_identity_apply(v) == v.
//
// Expected: rc=0.

import "stdlib/rods/kinematics.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_vec3_components() -> i64 {
    let v: i64 = vec3_f64(1.0, 2.0, 3.0);
    if close(vec3_x_f64(v), 1.0, 1e-12) != 1 { vec3_free(v); return 1; };
    if close(vec3_y_f64(v), 2.0, 1e-12) != 1 { vec3_free(v); return 2; };
    if close(vec3_z_f64(v), 3.0, 1e-12) != 1 { vec3_free(v); return 4; };
    vec3_free(v);
    return 0;
}

fn check_cross_product() -> i64 {
    let xhat: i64 = vec3_f64(1.0, 0.0, 0.0);
    let yhat: i64 = vec3_f64(0.0, 1.0, 0.0);
    let zhat: i64 = vec3_cross(xhat, yhat);
    if close(vec3_x_f64(zhat), 0.0, 1e-12) != 1 { return 8; };
    if close(vec3_y_f64(zhat), 0.0, 1e-12) != 1 { return 16; };
    if close(vec3_z_f64(zhat), 1.0, 1e-12) != 1 { return 32; };
    vec3_free(xhat); vec3_free(yhat); vec3_free(zhat);
    return 0;
}

fn check_identity_quat_rotation() -> i64 {
    let v: i64 = vec3_f64(2.0, 3.0, 5.0);
    let q: i64 = quat_identity();
    let r: i64 = quat_rotate(q, v);
    if close(vec3_x_f64(r), 2.0, 1e-9) != 1 { return 64; };
    if close(vec3_y_f64(r), 3.0, 1e-9) != 1 { return 128; };
    if close(vec3_z_f64(r), 5.0, 1e-9) != 1 { return 256; };
    vec3_free(v); quat_free(q); vec3_free(r);
    return 0;
}

fn check_identity_pose_apply() -> i64 {
    let v: i64 = vec3_f64(0.5, 0.0 - 1.5, 7.0);
    let p: i64 = pose_identity();
    let r: i64 = pose_apply(p, v);
    if close(vec3_x_f64(r), 0.5, 1e-9) != 1 { return 512; };
    if close(vec3_y_f64(r), 0.0 - 1.5, 1e-9) != 1 { return 1024; };
    if close(vec3_z_f64(r), 7.0, 1e-9) != 1 { return 2048; };
    vec3_free(v); pose_free(p); vec3_free(r);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_vec3_components();
    fails = fails + check_cross_product();
    fails = fails + check_identity_quat_rotation();
    fails = fails + check_identity_pose_apply();
    return fails;
}
