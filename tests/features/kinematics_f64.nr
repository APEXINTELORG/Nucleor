// stdlib/rods/kinematics — `*_f64` ergonomic wrappers.
//
// v0.4.261: same pattern as v0.4.260's units_convert_f64 —
// hide the i64-bits-ABI behind f64-typed wrappers. Adopter
// writes `vec3_f64(1.0, 2.0, 3.0)` instead of the manual
// `vec3(f64_to_bits(1.0), f64_to_bits(2.0), f64_to_bits(3.0))`.
//
// Exercises Vec3 + Quaternion wrappers across construction,
// component access, dot product, norm, scale, axis-angle quat,
// and quat component readback.
//
// EXPECT: build success, runtime exit 0, output "OK kinematics_f64".

import "stdlib/rods/kinematics.nr"

fn main() -> i32 {
    // Vec3 construction + component round-trip.
    let v: i64 = vec3_f64(3.0, 4.0, 0.0);
    if v == 0 { print("FAIL vec3_f64"); return 1; };
    if (vec3_x_f64(v) as i32) != 3 { print("FAIL vec3_x_f64"); return 1; };
    if (vec3_y_f64(v) as i32) != 4 { print("FAIL vec3_y_f64"); return 1; };
    if (vec3_z_f64(v) as i32) != 0 { print("FAIL vec3_z_f64"); return 1; };

    // Norm: ||(3,4,0)|| = 5.
    let n: f64 = vec3_norm_f64(v);
    if (n as i32) != 5 { print("FAIL vec3_norm_f64"); return 1; };

    // Dot product: (3,4,0) · (1,0,0) = 3.
    let xhat: i64 = vec3_f64(1.0, 0.0, 0.0);
    let d: f64 = vec3_dot_f64(v, xhat);
    if (d as i32) != 3 { print("FAIL vec3_dot_f64"); return 1; };

    // Scale: (3,4,0) * 2 = (6,8,0). norm = 10.
    let v2: i64 = vec3_scale_f64(v, 2.0);
    let n2: f64 = vec3_norm_f64(v2);
    if (n2 as i32) != 10 { print("FAIL vec3_scale_f64"); return 1; };

    vec3_free(v);
    vec3_free(xhat);
    vec3_free(v2);

    // Quaternion: identity (w=1, x=y=z=0).
    let q_id: i64 = quat_f64(1.0, 0.0, 0.0, 0.0);
    if q_id == 0 { print("FAIL quat_f64"); return 1; };
    if (quat_w_f64(q_id) as i32) != 1 { print("FAIL quat_w_f64"); return 1; };
    if (quat_x_f64(q_id) as i32) != 0 { print("FAIL quat_x_f64"); return 1; };
    if (quat_y_f64(q_id) as i32) != 0 { print("FAIL quat_y_f64"); return 1; };
    if (quat_z_f64(q_id) as i32) != 0 { print("FAIL quat_z_f64"); return 1; };
    quat_free(q_id);

    // Axis-angle: rotation 0 around z-axis = identity.
    let zhat: i64 = vec3_f64(0.0, 0.0, 1.0);
    let q_zero: i64 = quat_from_axis_angle_f64(zhat, 0.0);
    if q_zero == 0 { print("FAIL quat_from_axis_angle_f64"); return 1; };
    // w of (axis, 0) = cos(0/2) = 1.
    if (quat_w_f64(q_zero) as i32) != 1 { print("FAIL aa w==1"); return 1; };
    quat_free(q_zero);
    vec3_free(zhat);

    print("OK kinematics_f64");
    0
}
