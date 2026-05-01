// stdlib/rods/fk_chain — `*_f64` ergonomic wrappers.
//
// v0.4.266: forward-kinematics chain construction now takes
// f64-typed DH params + base offsets + joint axes; link pose
// readback returns f64 directly. Adopters skip the per-call
// `f64_to_bits` / `f64_from_bits` plumbing.
//
// Build a 2-link planar arm: link 1 = revolute joint about z
// at origin, link 2 = revolute joint about z offset by 1.0 m
// in x. With both joint vars = 0, the end-effector should be
// at (2, 0, 0) (link 1 base + link 2 offset) and identity
// quaternion. We don't run the FK update here (that needs a
// caller-allocated double[] for the joint vars buffer); just
// verify the constructors + readers compile and run through
// the f64 wrappers.
//
// EXPECT: build success, runtime exit 0, output "OK fk_chain_f64".

import "stdlib/rods/fk_chain.nr"

fn main() -> i32 {
    let ch: i64 = fk_chain_new();
    if ch == 0 { print("FAIL fk_chain_new"); return 1; };

    // Add a DH joint via the f64 wrapper:
    //   alpha=0, a=1.0, d=0, theta=0.
    let j0: i64 = fk_chain_add_dh_joint_f64(ch, 0.0, 1.0, 0.0, 0.0);
    if j0 != 0 { print("FAIL add_dh_joint_f64"); return 1; };

    // Add a generic revolute joint about z, offset x=1.0:
    //   joint_type = fk_revolute() = 0
    //   off = (1, 0, 0); off_quat = identity (1, 0, 0, 0);
    //   axis = (0, 0, 1).
    let j1: i64 = fk_chain_add_joint_f64(ch, fk_revolute(),
        1.0, 0.0, 0.0,
        1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0);
    if j1 != 1 { print("FAIL add_joint_f64"); return 1; };

    // Joint count == 2.
    if fk_chain_count(ch) != 2 { print("FAIL count"); return 1; };

    // Read joint axis dim 2 (z) on j1 — expect 1.0.
    let az: f64 = fk_chain_joint_axis_f64(ch, 1, 2);
    if (az as i32) != 1 { print("FAIL joint_axis_f64 z"); return 1; };

    // Read joint axis dim 0 (x) on j1 — expect 0.0.
    let ax: f64 = fk_chain_joint_axis_f64(ch, 1, 0);
    if (ax as i32) != 0 { print("FAIL joint_axis_f64 x"); return 1; };

    fk_chain_free(ch);

    print("OK fk_chain_f64");
    0
}
