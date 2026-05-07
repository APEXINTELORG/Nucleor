// EXPECT: rc=0
// v0845 Lane 5 / Queue 5B — timestamped typed TF wrappers smoke.
// tf_add_frame_at_typed validates canonical frame IDs at runtime;
// tf_set_pose_at_typed and tf_lookup_at_typed exercise the
// timestamped surface end-to-end. Uses raw double[3]/double[4]
// pointer buffers per the tf rod convention (see also
// tests/features/tf_timestamped_lookup_smoke.nr).

import "stdlib/rods/tf.nr"
import "stdlib/rods/kinematics_frame.nr"
import "stdlib/rods/f64_buffer.nr"

fn set_t(h: i64, x: f64, y: f64, z: f64) {
    f64_buf_set(h, 0, x);
    f64_buf_set(h, 1, y);
    f64_buf_set(h, 2, z);
}

fn set_q_identity(h: i64) {
    f64_buf_set(h, 0, 1.0);
    f64_buf_set(h, 1, 0.0);
    f64_buf_set(h, 2, 0.0);
    f64_buf_set(h, 3, 0.0);
}

fn main() -> i32 {
    let h: i64 = tf_new(16);
    let world: i64 = kinematics_frame_id_world();
    let base: i64 = kinematics_frame_id_base();
    let cam: i64 = kinematics_frame_id_camera();

    let t: i64 = f64_buf_new(3);
    let q: i64 = f64_buf_new(4);
    let t_out: i64 = f64_buf_new(3);
    let q_out: i64 = f64_buf_new(4);
    if h == 0 || t == 0 || q == 0 || t_out == 0 || q_out == 0 { return 1; };

    set_q_identity(q);
    let stamp1: i64 = f64_to_bits(1.0);

    // Add world as root (parent_id = -1 = unknown sentinel = root).
    set_t(t, 0.0, 0.0, 0.0);
    if tf_add_frame_at_typed(h, world, 0 - 1, stamp1, t, q) != 1 { return 2; };

    // Add base relative to world (parent = world = 0).
    if tf_add_frame_at_typed(h, base, world, stamp1, t, q) != 1 { return 3; };

    // Add camera relative to base (parent = base = 1).
    set_t(t, 1.0, 0.0, 0.0);
    if tf_add_frame_at_typed(h, cam, base, stamp1, t, q) != 1 { return 4; };

    // Lookup camera in world frame.
    if tf_lookup_at_typed(h, world, cam, stamp1, t_out, q_out) != 1 { return 5; };

    // Update camera at t=2.0.
    let stamp2: i64 = f64_to_bits(2.0);
    set_t(t, 2.0, 0.0, 0.0);
    if tf_set_pose_at_typed(h, cam, stamp2, t, q) != 1 { return 6; };

    // Validate non-canonical frame ID rejected at runtime (returns 0).
    if tf_add_frame_at_typed(h, 999, world, stamp1, t, q) != 0 { return 7; };

    tf_free(h);
    return 0;
}
