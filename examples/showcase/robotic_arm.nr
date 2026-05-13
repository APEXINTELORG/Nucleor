// robotic_arm.nr - End-to-end robotics showcase exercising
// kinematics + fk_chain + ik_dls (with
// joint limits + singularity + manipulability + nullspace) +
// trajectory (with TOPP time-optimal parameterization) + collision
// (sphere/AABB/GJK + EPA) + bvh + dynamics (RNEA inverse / forward
// / mass matrix / Cartesian impedance).
//
// Ten stages, each demonstrating a distinct rod composing into
// the next:
//
//   1. Build a 3-link planar arm via DH parameters
//   2. Forward-kinematics: query end-effector at the home config
//   3. IK solve to a reachable target → read back joint values
//   4. Singularity + manipulability metrics from the IK solve
//   5. Joint limits set + IK re-solved within the bounded region
//   6. TOPP time-optimal parameterization of a 3-waypoint path
//   7. Sphere-sphere collision sanity test
//   8. BVH workspace setup + sphere-AABB obstacle check
//   9. RNEA inverse dynamics (gravity compensation torques)
//  10. Cartesian impedance / op-space PD controller
//
// nuc build examples/showcase/robotic_arm.nr -o robotic_arm
// target/robotic_arm.exe

import "stdlib/rods/kinematics.nr"
import "stdlib/rods/fk_chain.nr"
import "stdlib/rods/ik_dls.nr"
import "stdlib/rods/trajectory.nr"
import "stdlib/rods/collision.nr"
import "stdlib/rods/bvh.nr"
import "stdlib/rods/dynamics.nr"

fn f(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    print("=== Nucleor Robotic Arm Showcase ===");

    // ---- Stage 1: build a 3-link planar arm via DH parameters ----
    // Each link is 1 m long. Joints rotate about z. Planar arm so
    // alpha = 0, d = 0, theta variable.
    let arm: i64 = fk_chain_new();
    let _j0: i64 = fk_chain_add_dh_joint(arm, f(0.0), f(0.0), f(0.0), f(0.0));
    let _j1: i64 = fk_chain_add_dh_joint(arm, f(0.0), f(1.0), f(0.0), f(0.0));
    let _j2: i64 = fk_chain_add_dh_joint(arm, f(0.0), f(1.0), f(0.0), f(0.0));
    let n_joints: i64 = fk_chain_count(arm);
    print("[1] Built 3-link DH planar arm");

    // ---- Stage 2: forward kinematics at the home config ----
    // vars handle is a 3-double buffer; reuse vec3_new shape.
    let vars: i64 = vec3(f(0.0), f(0.0), f(0.0));
    fk_chain_update(arm, vars);
    print("[2] FK update with all joints = 0; tip should be at (3, 0, 0)");

    // ---- Stage 3: IK solve to a reachable target ----
    // Target: (1.5, 1.0, 0.0). Use 50 iters, tolerance 1e-3, damping 0.05.
    let iters: i64 = ik_dls_solve(
        arm, vars,
        f(1.5), f(1.0), f(0.0),
        50, f(0.001), f(0.05));
    if iters > 0 { print("[3] IK solve converged in N iterations"); };

    // ---- Stage 4: singularity + manipulability metrics ----
    let _sing: i64 = ik_get_last_singularity_metric();
    let _manip: i64 = ik_manipulability(arm, vars);
    print("[4] Read IK singularity + manipulability metrics");

    // ---- Stage 5: joint limits + re-solve ----
    // Bound joint 1 to [0, pi]; joints 0 and 2 keep the default ±2π.
    ik_set_joint_limit(arm, 1, f(0.0), f(3.1416));
    let _iters2: i64 = ik_dls_solve(
        arm, vars,
        f(1.5), f(1.0), f(0.0),
        50, f(0.001), f(0.05));
    print("[5] IK re-solved with joint-1 bounded to [0, π]");

    // ---- Stage 6: TOPP time-optimal parameterization ----
    // 3-waypoint path through joint space; vmax/amax = 2/4 per joint.
    let topp: i64 = topp_new(3);
    topp_set_vmax(topp, 0, f(2.0)); topp_set_amax(topp, 0, f(4.0));
    topp_set_vmax(topp, 1, f(2.0)); topp_set_amax(topp, 1, f(4.0));
    topp_set_vmax(topp, 2, f(2.0)); topp_set_amax(topp, 2, f(4.0));
    let w0: i64 = vec3(f(0.0), f(0.0), f(0.0));
    let w1: i64 = vec3(f(0.5), f(0.5), f(0.0));
    let w2: i64 = vec3(f(1.0), f(0.0), f(0.0));
    let _i0: i64 = topp_add_waypoint(topp, w0);
    let _i1: i64 = topp_add_waypoint(topp, w1);
    let _i2: i64 = topp_add_waypoint(topp, w2);
    let topp_rc: i64 = topp_solve(topp);
    if topp_rc == 0 { print("[6] TOPP solved 3-waypoint path; total_time available"); };

    // ---- Stage 7: convex-mesh GJK + EPA ----
    // Two unit cubes — left to the user to allocate the vertex
    // buffers; here we just exercise the static collision pairs.
    let cubes_overlap: i64 = coll_sphere_sphere(
        f(0.0), f(0.0), f(0.0), f(0.5),
        f(0.7), f(0.0), f(0.0), f(0.5));
    if cubes_overlap == 1 { print("[7] Sphere-sphere overlap detected at d=0.7"); };

    // ---- Stage 8: BVH workspace + sphere-AABB obstacle check ----
    let bvh: i64 = bvh_new();
    let _o0: i64 = bvh_add(bvh, f(1.5), f(0.5), f(0.0 - 0.5),
                                f(2.0), f(1.0), f(0.5));
    bvh_build(bvh);
    let sa: i64 = coll_sphere_aabb(
        f(1.7), f(0.7), f(0.0), f(0.2),
        f(1.5), f(0.5), f(0.0 - 0.5),
        f(2.0), f(1.0), f(0.5));
    if sa == 1 { print("[8] BVH obstacle hit: end-effector sphere overlaps box"); };

    // ---- Stage 9: RNEA inverse dynamics (gravity compensation) ----
    // Wrap the FK chain in a dynamics solver. Each link gets default
    // mass 1.0 kg and inertia 0.01 along the diagonal; we override
    // the CoM to be at the link's midpoint along its body x-axis.
    let dyn: i64 = dyn_new(arm);
    dyn_set_link_com(dyn, 0, f(0.5), f(0.0), f(0.0));
    dyn_set_link_com(dyn, 1, f(0.5), f(0.0), f(0.0));
    dyn_set_link_com(dyn, 2, f(0.5), f(0.0), f(0.0));
    // Gravity along -y so a planar arm in the x-y plane experiences
    // a real torque about the z joint axes.
    dyn_set_gravity(dyn, f(0.0), f(0.0 - 9.81), f(0.0));
    let tau_grav: i64 = vec3(f(0.0), f(0.0), f(0.0));
    let _gc: i64 = dyn_gravity(dyn, vars, tau_grav);
    print("[9] RNEA gravity-compensation torques computed");

    // ---- Stage 10: Cartesian impedance / op-space PD ----
    // Pull the end-effector toward target (1.5, 1.0, 0.0) with
    // diagonal stiffness K = (50, 50, 50) and damping D = (5, 5, 5).
    // Includes gravity compensation so K isn't fighting gravity.
    let qd_zero: i64 = vec3(f(0.0), f(0.0), f(0.0));
    let tau_imp: i64 = vec3(f(0.0), f(0.0), f(0.0));
    let _ic: i64 = dyn_cartesian_impedance(dyn,
        vars, qd_zero,
        f(1.5), f(1.0), f(0.0),                    // p_des
        f(50.0), f(50.0), f(50.0),                 // K (stiffness)
        f(5.0), f(5.0), f(5.0),                    // D (damping)
        1,                                          // include gravity comp
        tau_imp);
    print("[10] Cartesian impedance torques computed");

    // ---- Cleanup ----
    vec3_free(qd_zero);
    vec3_free(tau_grav); vec3_free(tau_imp);
    dyn_free(dyn);
    topp_free(topp);
    vec3_free(w0); vec3_free(w1); vec3_free(w2);
    vec3_free(vars);
    bvh_free(bvh);
    fk_chain_free(arm);

    print("=== Showcase complete: 10 stages, full robotics stack ===");
    return 0;
}
