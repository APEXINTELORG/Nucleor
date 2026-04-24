// rods/tf — Hierarchical coordinate-frame transform tree.
//
// ROS-style "tf" tree: each frame has an integer ID, a parent ID,
// and a pose `(t, q)` expressed in the parent frame. The root has
// `parent_id = -1`. Lookup between any two frames composes
// transforms along the path through the tree.
//
// Convention: each stored pose `(t_i, q_i)` is the transform that
// takes a point in frame `i` to its parent's frame:
//
//   p_parent = q_i · p_i · q_i⁻¹ + t_i
//
// `tf_lookup(source, target, t_out, q_out)` writes the pose of
// `target` expressed in `source`'s frame, matching ROS
// `lookupTransform(source, target)` semantics.
//
// Workflow:
//
//   import "stdlib/rods/tf.nr"
//
//   let tf = tf_new(max_frames);
//
//   // Register frames. Use any integer IDs; caller manages the
//   // name → id mapping (e.g. via hashmap_str.nr).
//   tf_add_frame(tf, ROOT,   -1,    t_zero, q_id);    // root at origin
//   tf_add_frame(tf, BASE,   ROOT,  t_base, q_base);  // robot base
//   tf_add_frame(tf, ARM,    BASE,  t_arm,  q_arm);   // arm relative to base
//   tf_add_frame(tf, GRIPPER, ARM,  t_grp,  q_grp);   // gripper relative to arm
//
//   // Update poses live (e.g. as the robot moves):
//   tf_set_pose(tf, BASE, t_base_new, q_base_new);
//
//   // Lookup gripper pose in world (root) frame:
//   tf_lookup(tf, ROOT, GRIPPER, t_out, q_out);
//
//   tf_free(tf);
//
// **Limitations** (string-keyed frames / time-stamped buffer / lazy
// caching land in v0.6 if needed):
// - Integer frame IDs only — caller manages name→id mapping.
// - Single tree only (no disconnected forest).
// - No time stamps or interpolation buffer; for time-varying
//   transforms call `tf_set_pose` between lookups.
// - Brute-force ancestor walk: `O(depth)` per lookup, max depth 64.
//
// See `stdlib/runtime/tf_rt.c`.
#cfile "../runtime/tf_rt.c"

extern fn nuc_tf_new(max_frames: i64) -> i64;
extern fn nuc_tf_add_frame(h: i64, frame_id: i64, parent_id: i64,
    t_ptr: i64, q_ptr: i64) -> i64;
extern fn nuc_tf_set_pose(h: i64, frame_id: i64, t_ptr: i64, q_ptr: i64) -> i64;
extern fn nuc_tf_lookup(h: i64, source_id: i64, target_id: i64,
    t_out_ptr: i64, q_out_ptr: i64) -> i64;
extern fn nuc_tf_free(h: i64);

fn tf_new(max_frames: i64) -> i64 { return nuc_tf_new(max_frames); }

// Register (or re-register) a frame. `parent_id = -1` for root.
// `t_ptr` is `double[3]`, `q_ptr` is `double[4]` (scalar-first).
// Returns 1 on success.
fn tf_add_frame(h: i64, frame_id: i64, parent_id: i64, t_ptr: i64, q_ptr: i64) -> i64 {
    return nuc_tf_add_frame(h, frame_id, parent_id, t_ptr, q_ptr);
}

// Update pose of an existing frame. Returns 1 on success.
fn tf_set_pose(h: i64, frame_id: i64, t_ptr: i64, q_ptr: i64) -> i64 {
    return nuc_tf_set_pose(h, frame_id, t_ptr, q_ptr);
}

// Lookup pose of `target` expressed in `source`'s frame.
// Writes (t_out, q_out). Returns 1 on success, 0 if either frame
// is unregistered or disconnected from the tree.
fn tf_lookup(h: i64, source_id: i64, target_id: i64,
    t_out_ptr: i64, q_out_ptr: i64) -> i64
{
    return nuc_tf_lookup(h, source_id, target_id, t_out_ptr, q_out_ptr);
}

fn tf_free(h: i64) { nuc_tf_free(h); }
