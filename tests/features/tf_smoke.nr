// v0.8.245 stdlib/rods/tf.nr first test coverage.
//
// Hierarchical coordinate-frame transform tree (ROS-style).
// Pre-v0.8.245: zero coverage on the standalone rod. add_frame
// / set_pose / lookup all use raw double[] pointers (t[3], q[4])
// for poses; deferred to dedicated TF / URDF ships.
//
// Locks four lifecycle invariants:
//
//   1. tf_new returns valid handle — non-zero for reasonable
//      max_frames.
//   2. Multiple distinct trees — two constructions →
//      distinct handles (frame stores aren't aliased).
//   3. Small max_frames is allowed — max=1 still works.
//   4. tf_free does not crash on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/tf.nr"

fn check_new_valid() -> i64 {
    let h: i64 = tf_new(64);
    if h == 0 { return 1; };
    tf_free(h);
    return 0;
}

fn check_distinct_trees() -> i64 {
    let a: i64 = tf_new(16);
    let b: i64 = tf_new(16);
    let same: i64 = if a == b { 1 } else { 0 };
    tf_free(a);
    tf_free(b);
    if same == 1 { return 2; };
    return 0;
}

fn check_small_max_frames() -> i64 {
    let h: i64 = tf_new(1);
    if h == 0 { return 4; };
    tf_free(h);
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = tf_new(8);
    tf_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_distinct_trees();
    fails = fails + check_small_max_frames();
    fails = fails + check_free_non_crashing();
    return fails;
}
