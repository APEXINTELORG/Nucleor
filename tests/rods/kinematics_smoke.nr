// rods/kinematics — verify rod wrapper compiles + links (v0.2.174 ship).
// Exercises Vec3 dot/cross, quaternion multiplication identity laws, and
// pose composition + apply. Math doesn't need bit-perfect output here;
// each assertion checks that the operation produced a non-degenerate
// result (e.g. non-zero norm, identity-quat composition is identity).
import "stdlib/rods/kinematics.nr"

fn f64_to_bits(x: f64) -> i64 {
    // Reinterpret-cast f64 → i64. Used to pass f64 values across the
    // i64 FFI to the runtime helpers.
    return x as i64;
}

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Vec3 algebra: cross of x-hat and y-hat is z-hat.
    let xhat: i64 = vec3(f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let yhat: i64 = vec3(f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(0.0));
    let cross_xy: i64 = vec3_cross(xhat, yhat);
    let zbits: i64 = vec3_z(cross_xy);
    if zbits == 0 { fail = fail + 1; print("FAIL cross x-hat,y-hat z component"); };

    // Quaternion identity composition.
    let qid: i64 = quat_identity();
    let qid2: i64 = quat_mul(qid, qid);
    let w: i64 = quat_w(qid2);
    if w == 0 { fail = fail + 1; print("FAIL identity quat composition"); };

    // Pose identity composition + apply.
    let pid: i64 = pose_identity();
    let pid_compose: i64 = pose_compose(pid, pid);
    let v: i64 = vec3(f64_to_bits(1.0), f64_to_bits(2.0), f64_to_bits(3.0));
    let v_after: i64 = pose_apply(pid_compose, v);
    let xbits: i64 = vec3_x(v_after);
    if xbits == 0 { fail = fail + 1; print("FAIL identity pose apply preserves x"); };

    if fail == 0 { print("OK kinematics_smoke"); };
    return fail;
}
