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
// **Limitations** (string-keyed frames / forest / lazy caching land
// in v0.6 if needed):
// - Integer frame IDs only — caller manages name→id mapping.
// - Single tree only (no disconnected forest).
// - Time-stamped interpolation keeps the latest two samples per
//   frame only; deeper history buffers are follow-up work.
// - Brute-force ancestor walk: `O(depth)` per lookup, max depth 64.
//
// See `stdlib/runtime/tf_rt.c`.
#cfile "../runtime/tf_rt.c"

extern fn nuc_tf_new(max_frames: i64) -> i64;
extern fn nuc_tf_add_frame(h: i64, frame_id: i64, parent_id: i64,
    t_ptr: i64, q_ptr: i64) -> i64;
extern fn nuc_tf_add_frame_at(h: i64, frame_id: i64, parent_id: i64,
    stamp_b: i64, t_ptr: i64, q_ptr: i64) -> i64;
extern fn nuc_tf_set_pose(h: i64, frame_id: i64, t_ptr: i64, q_ptr: i64) -> i64;
extern fn nuc_tf_set_pose_at(h: i64, frame_id: i64,
    stamp_b: i64, t_ptr: i64, q_ptr: i64) -> i64;
extern fn nuc_tf_lookup(h: i64, source_id: i64, target_id: i64,
    t_out_ptr: i64, q_out_ptr: i64) -> i64;
extern fn nuc_tf_lookup_at(h: i64, source_id: i64, target_id: i64,
    stamp_b: i64, t_out_ptr: i64, q_out_ptr: i64) -> i64;
extern fn nuc_tf_free(h: i64);

fn tf_new(max_frames: i64) -> i64 { return nuc_tf_new(max_frames); }

// Register (or re-register) a frame. `parent_id = -1` for root.
// `t_ptr` is `double[3]`, `q_ptr` is `double[4]` (scalar-first).
// Returns 1 on success.
fn tf_add_frame(h: i64, frame_id: i64, parent_id: i64, t_ptr: i64, q_ptr: i64) -> i64 {
    return nuc_tf_add_frame(h, frame_id, parent_id, t_ptr, q_ptr);
}

// Register a frame with an initial timestamped pose. `stamp` is an
// f64 bit-cast timestamp in caller-defined units.
fn tf_add_frame_at(h: i64, frame_id: i64, parent_id: i64,
    stamp_b: i64, t_ptr: i64, q_ptr: i64) -> i64 {
    return nuc_tf_add_frame_at(h, frame_id, parent_id, stamp_b, t_ptr, q_ptr);
}

// Update pose of an existing frame. Returns 1 on success.
fn tf_set_pose(h: i64, frame_id: i64, t_ptr: i64, q_ptr: i64) -> i64 {
    return nuc_tf_set_pose(h, frame_id, t_ptr, q_ptr);
}

// Update pose with a timestamp. The runtime keeps the previous and
// current sample and interpolates between them in `tf_lookup_at`.
fn tf_set_pose_at(h: i64, frame_id: i64,
    stamp_b: i64, t_ptr: i64, q_ptr: i64) -> i64 {
    return nuc_tf_set_pose_at(h, frame_id, stamp_b, t_ptr, q_ptr);
}

// Lookup pose of `target` expressed in `source`'s frame.
// Writes (t_out, q_out). Returns 1 on success, 0 if either frame
// is unregistered or disconnected from the tree.
fn tf_lookup(h: i64, source_id: i64, target_id: i64,
    t_out_ptr: i64, q_out_ptr: i64) -> i64
{
    return nuc_tf_lookup(h, source_id, target_id, t_out_ptr, q_out_ptr);
}

// Timestamped lookup. Each frame with two timestamped samples is
// interpolated at `stamp`; static or single-sample frames use their
// stored pose.
fn tf_lookup_at(h: i64, source_id: i64, target_id: i64,
    stamp_b: i64, t_out_ptr: i64, q_out_ptr: i64) -> i64
{
    return nuc_tf_lookup_at(h, source_id, target_id, stamp_b, t_out_ptr, q_out_ptr);
}

fn tf_free(h: i64) { nuc_tf_free(h); }

// === R07-D2 Phase 1 (v0.8.268) — typed TF wrappers ===
//
// Per audit `BUILD_PLAN_R07_robotics_control.md` §1 R07-D2 (HIGH):
// pre-v0.8.268 the TF rod accepted any i64 as frame_id, so adopters
// could pass arbitrary integers (1, 2, 47, -999) outside the type
// checker's visibility. The typed wrappers below restrict callers
// to the canonical kinematics_frame ID range (0..7 or -1) and reject
// out-of-range IDs at runtime.
//
// Adopter pattern (typed):
//
//   import "stdlib/rods/tf.nr"
//   import "stdlib/rods/kinematics_frame.nr"
//
//   let h: i64 = tf_new(16);
//   let cam: i64 = kinematics_frame_id_camera();
//   let base: i64 = kinematics_frame_id_base();
//   let _ = tf_add_frame_typed(h, cam, base, t_ptr, q_ptr);
//
// Raw `tf_add_frame` / `tf_set_pose` / `tf_lookup` remain available
// for adopters who manage their own ID space (e.g. URDF link
// indices). Phase 2 promotes the typed wrappers to compile-time
// type-checked Pose<F> per RFC-0046 Phase B.

// Returns 1 if `id` is in the canonical range (0..7 inclusive or
// -1 sentinel), 0 otherwise.
fn tf_is_canonical_frame_id(id: i64) -> i64 {
    if id == 0 - 1 { return 1; };  // unknown sentinel
    if id >= 0 && id <= 7 { return 1; };
    return 0;
}

// Typed `tf_add_frame`: validates both `frame_id` and `parent_id`
// are canonical kinematics_frame IDs before forwarding. Returns
// 0 on validation failure (does NOT call the raw API), or the raw
// API's result (1 success / 0 failure) on validation success.
fn tf_add_frame_typed(h: i64, frame_id: i64, parent_id: i64,
    t_ptr: i64, q_ptr: i64) -> i64
{
    if tf_is_canonical_frame_id(frame_id) == 0 { return 0; };
    if tf_is_canonical_frame_id(parent_id) == 0 { return 0; };
    return nuc_tf_add_frame(h, frame_id, parent_id, t_ptr, q_ptr);
}

// Typed `tf_set_pose`: validates `frame_id` is canonical.
fn tf_set_pose_typed(h: i64, frame_id: i64, t_ptr: i64, q_ptr: i64) -> i64 {
    if tf_is_canonical_frame_id(frame_id) == 0 { return 0; };
    return nuc_tf_set_pose(h, frame_id, t_ptr, q_ptr);
}

// Typed `tf_lookup`: validates both source and target are canonical.
fn tf_lookup_typed(h: i64, source_id: i64, target_id: i64,
    t_out_ptr: i64, q_out_ptr: i64) -> i64
{
    if tf_is_canonical_frame_id(source_id) == 0 { return 0; };
    if tf_is_canonical_frame_id(target_id) == 0 { return 0; };
    return nuc_tf_lookup(h, source_id, target_id, t_out_ptr, q_out_ptr);
}

// === v0845 Lane 5 / Queue 5B — typed timestamped wrappers ===
//
// Mirrors the v0.8.268 typed wrappers above for the timestamped TF
// surface (`tf_add_frame_at`, `tf_set_pose_at`, `tf_lookup_at`).
// Each wrapper validates the frame IDs are in the canonical
// kinematics_frame range (0..7 inclusive or -1 unknown) before
// forwarding to the underlying nuc_tf_*_at. Returns 0 on validation
// failure (does NOT call the raw API), or the raw API's result
// on validation success.
//
// Adopter pattern (timestamped + typed):
//
//   import "stdlib/rods/tf.nr"
//   import "stdlib/rods/kinematics_frame.nr"
//
//   let h: i64 = tf_new(16);
//   let cam: i64 = kinematics_frame_id_camera();
//   let base: i64 = kinematics_frame_id_base();
//   let stamp1_b: i64 = f64_to_bits(1.0);
//   let stamp2_b: i64 = f64_to_bits(2.0);
//   let _ = tf_add_frame_at_typed(h, cam, base, stamp1_b, t_ptr, q_ptr);
//   let _ = tf_set_pose_at_typed(h, cam, stamp2_b, t_ptr2, q_ptr2);
//   let _ = tf_lookup_at_typed(h, base, cam, stamp1_b, t_out, q_out);
//
// Raw `tf_add_frame_at` / `tf_set_pose_at` / `tf_lookup_at` remain
// available for adopters managing their own ID space; treat them
// as migration surfaces and prefer the typed forms in new code.

fn tf_add_frame_at_typed(h: i64, frame_id: i64, parent_id: i64,
    stamp_b: i64, t_ptr: i64, q_ptr: i64) -> i64
{
    if tf_is_canonical_frame_id(frame_id) == 0 { return 0; };
    if tf_is_canonical_frame_id(parent_id) == 0 { return 0; };
    return nuc_tf_add_frame_at(h, frame_id, parent_id, stamp_b, t_ptr, q_ptr);
}

fn tf_set_pose_at_typed(h: i64, frame_id: i64,
    stamp_b: i64, t_ptr: i64, q_ptr: i64) -> i64
{
    if tf_is_canonical_frame_id(frame_id) == 0 { return 0; };
    return nuc_tf_set_pose_at(h, frame_id, stamp_b, t_ptr, q_ptr);
}

fn tf_lookup_at_typed(h: i64, source_id: i64, target_id: i64,
    stamp_b: i64, t_out_ptr: i64, q_out_ptr: i64) -> i64
{
    if tf_is_canonical_frame_id(source_id) == 0 { return 0; };
    if tf_is_canonical_frame_id(target_id) == 0 { return 0; };
    return nuc_tf_lookup_at(h, source_id, target_id, stamp_b, t_out_ptr, q_out_ptr);
}
