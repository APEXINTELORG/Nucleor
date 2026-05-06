# Nucleor — Robotics and Control Stack Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS`.

---

# Part I — Definition

## 1.1. The robotics pillar

25+ rods covering FK/IK/TOPP/GJK/RRT/PRM/A*/SE3/UKF/CHOMP/WBC/ZMP/AHRS/URDF. The breadth is genuinely strong; the depth has gaps that matter for real robot deployments.

**Headline finding 1: frame-typing safety is Phase A only — markers exist but compiler does not enforce.** All handles are plain i64. Mixing camera-frame and base-frame poses is still a silent runtime error. **This is the Mars Climate Orbiter failure mode and it's still live.**

**Headline finding 2: end-to-end IK→plan→trajectory→endpoint smoke coverage now exists, but production-grade 6-DOF robotics validation remains open.** The v0.8 helper1 slice added a typed `f64_buffer` scratch surface and `tests/features/robo14_end_to_end_smoke.nr`, which closes the old "no Vec<f64> plumbing" blocker for raw `double[]` rod APIs. Remaining work is the harder 6-DOF/orientation/obstacle/dynamics variant.

**Headline finding 3: none of the robotics rods carry `#[no_alloc]+#[deadline]` annotations.** A robot control loop needing hard-RT cannot use these rods without either pre-allocating handles or annotating the rod itself. **No documented protocol** for hard-RT use of the robotics stack.

---

# Part II — Gap Inventory

## ROBO-1 — TOPP is kinematic-only, piecewise-linear paths only — **MEDIUM**
Comment: "Pure kinematic (no torque/dynamics constraints)." TOPP-RA (convex per-step constraints) deferred to v0.6. Forward+backward pass on `b(s) = (ds/dt)²` ignores actuator torque curves. Time-optimal claim approximate for real robots.

## ROBO-2 — DMP has no multi-DOF batch wrapper — **LOW**
"Multi-DOF: instantiate one DMP per joint." No `dmp_multi_new`/`dmp_multi_step` for whole joint-vector. Forces repetitive per-joint calls; prevents learning cross-DOF coupling.

**2026-05-06 update:** Phase 1 multi-DOF batch wrapper now exists. `dmp_multi_new`, `dmp_multi_learn`, `dmp_multi_reset`, and `dmp_multi_step` own one scalar DMP per joint while accepting sample-major joint-vector buffers; `tests/features/dmp_multi_smoke.nr` proves 2-DOF train/reset/step output through public f64 scratch buffers. Remaining ROBO-2 work: true coupled-basis learning across DOFs rather than independent per-joint DMPs.

## ROBO-3 — IK has no analytical IK path — **MEDIUM**
`ik_dls.nr` purely numerical (finite-difference Jacobian). Standard 6-DOF manipulators (Puma/UR/Kuka) have closed-form solutions: 8 branches, 100× faster, singularity-exact. Not present.

## ROBO-4 — IK nullspace solver uses position-only Jacobian — **HIGH**
`nuc_ik_dls_solve_nullspace` uses 3-DOF position Jacobian. For n≥7 DOF arms needing orientation + posture simultaneously, you need 6×n Jacobian in nullspace path. 6-DOF path doesn't expose nullspace variant.

## ROBO-5 — TF tree: integer IDs, no timestamps, no forest — **HIGH**
Limitations: integer-only IDs (caller maintains name→id map), single tree only, no time-stamped buffer or interpolation. Real sensor-fusion produces transforms at different frequencies (camera 30 Hz, lidar 10 Hz); without time-indexed buffer, `tf_set_pose` races with async sources.

## ROBO-6 — URDF parser flattens branching topologies — **HIGH**
"Branching trees (humanoids) flattened to source-order." Parent/child relationships ignored. Humanoid, quadruped, parallel-chain robots cannot be correctly described. xacro macro expansion absent.

## ROBO-7 — Frame-type safety is Phase A only — **CRITICAL**
RFC-0046 Phase A ships zero-size marker structs and numeric IDs. **Phase B (compiler-side TYP-008 check) not yet shipped.** Mixing camera-frame and base-frame poses still silent runtime error. `kinematics.nr` still uses plain i64 handles — frame markers entirely opt-in and unchecked. **Mars Climate Orbiter failure mode live.**

## ROBO-8 — CHOMP uses approximated pre-conditioning — **MEDIUM**
"We approximate by clamping per-step move magnitude — much simpler, similar empirical behavior on typical paths." Full covariant A⁻¹∇F pre-conditioner absent. On narrow corridors or high-DOF robots, gradient poorly scaled; convergence degrades to vanilla GD.

## ROBO-9 — CHOMP joint-space only — no Cartesian variant — **MEDIUM**
Cartesian-space CHOMP (FK + Jacobian to optimize end-effector trajectory in task space) absent. Variant commonly used for manipulator reach-around tasks.

## ROBO-10 — WBC velocity-level only, no strict-priority, no torque box — **HIGH**
"Strict-priority hierarchy / box constraints / torque-level control land in v0.6." Velocity-level sufficient for kinematically-redundant arms but **not for torque-controlled legged robots.** Siciliano-Slotine null-space projection deferred.

## ROBO-11 — `twin_core` is quantum noise twin, not robot digital twin — **LOW** (naming only)
Rod named `twin_core.nr` is quantum simulator dual-core differentiable noise model. **No robotics digital twin rod:** no sim-to-real bridge, no physics-based state mirror. Naming misleading.

**2026-05-06 update:** Phase 1 naming mitigation exists without breaking compatibility. `stdlib/rods/quantum_twin.nr` is now the honest import alias for the existing quantum noise twin-core model, `twin_core.nr` documents that it is not a robotics digital-twin surface, and `tests/features/quantum_twin_alias_smoke.nr` locks the alias. Remaining ROBO-11 work: real robotics digital twin rod for sim-to-real / physics-based state mirroring.

## ROBO-12 — AHRS lacks magnetometer — yaw unobservable — **HIGH**
"Yaw is unobservable from accel... add magnetometer correction for absolute heading." Mahony filter with magnetometer and Madgwick variant absent. Drones, ground vehicles needing absolute heading cannot fuse compass.

**2026-05-06 update:** Phase 1 magnetometer fusion now exists. `ahrs_update_mag` adds a 9-DOF Mahony update path with calibrated body-frame magnetometer input and a world +X magnetic reference; `tests/features/ahrs_magnetometer_yaw_smoke.nr` proves yaw correction from an initial 90-degree heading error. Remaining ROBO-12 work: local declination/calibration helpers, stronger high-dynamics rejection, and a Madgwick variant.

## ROBO-13 — No CCD for OBB pairs or mesh-mesh — **MEDIUM**
CCD coverage: sphere-sphere, capsule-capsule, sphere-AABB, capsule-AABB. Missing OBB-OBB and convex-mesh-vs-mesh. Fast-moving rigid bodies with oriented geometry cannot be swept exactly.

**2026-05-06 update:** Phase 1 OBB coverage now exists. `coll_obb_obb` adds static SAT overlap for oriented boxes and `coll_ccd_obb_obb` computes exact time-of-impact for linearly translated OBB centers with fixed orientations; `tests/features/collision_obb_ccd_smoke.nr` locks overlap, clear, initial-hit, swept-hit, and swept-clear cases. Remaining ROBO-13 work: angular CCD and convex mesh-vs-mesh sweep.

## ROBO-14 — No end-to-end IK→plan→trajectory→endpoint test — **HIGH**
`robotic_arm.nr` showcase uses `ik_dls_solve` but **does NOT feed result into RRT/PRM, smooth with CHOMP, time-parameterize with TOPP, verify endpoint matches IK target.** Each stage independent; no test asserting full IK→plan→execute→verify loop closes with numeric correctness. Smoke tests are link-and-return ("Build-only smoke; full IK convergence test needs proper Vec<f64> plumbing").

**2026-05-06 update:** Phase 1 smoke coverage now exists. `stdlib/rods/f64_buffer.nr` + `stdlib/runtime/f64_buffer_rt.c` provide the missing typed scratch buffer for raw `double[]` rod APIs, and `tests/features/robo14_end_to_end_smoke.nr` now runs a deterministic planar arm through IK, RRT free-space planning, CHOMP smoothing, TOPP time-parameterization, and FK endpoint verification. Remaining ROBO-14 work is the production-grade variant: 6-DOF pose/orientation IK, nonzero collision/obstacle callbacks, and dynamics-aware timing.

## Cross-cutting risks
- **Frame-typing safety (highest severity).** All handles plain i64. `kinematics_frame.nr` markers cannot be attached to `kinematics.nr` Pose handle today; RFC-0046 Phase B is the only mechanism that catches camera→world substitution. Until then, every `pose_compose`/`tf_lookup`/`se3_apply` call site is potential silent miscompute. **Mars Climate Orbiter failure mode.**
- **Real-time composability.** Compiler has `#[no_alloc]`/`#[deadline]` infrastructure; **none of the robotics rods carry these annotations.** All rods heap-allocate. Robot control loop needing `#[no_alloc] #[deadline(500us)]` cannot use any of these rods without pre-allocating handles outside loop or annotating rod itself. **No documented protocol** for using these rods in hard-RT context.
- **End-to-end validation.** `robotic_arm.nr` is closest to integration test but doesn't assert numeric correctness of any output. IK convergence test punted to "direct C tests" not visible in OSS tree.
- **TOPP kinematic gap.** Marking trajectory "time-optimal" when torque limits not respected is specification claim the planner cannot fulfill on real hardware. Loaded links can saturate motor torque during deceleration.

---

# Part III — RFC

## 3.1. Goals
1. Ship RFC-0046 Phase B (compiler-side frame-type enforcement) — close the Mars Climate Orbiter failure mode.
2. Add end-to-end integration tests proving the full pipeline works numerically.
3. Annotate the robotics rods with `#[no_alloc]+#[deadline]` where feasible, document the protocol for hard-RT use.
4. Close the URDF branching gap — single biggest gap for adoption beyond serial arms.

## 3.2. Closure plan

**Phase 1 (emergency):**
- ROBO-7 P1: emit warning when `kinematics_frame` marker is declared but not enforced. "Frame-type check is Phase A — markers are advisory only. Phase B (compiler enforcement) tracked in RFC-0046."
- ROBO-14 P1: DONE for deterministic smoke coverage. `robo14_end_to_end_smoke.nr` now proves the raw-buffer plumbing and stage composition: IK solves a reachable target, RRT plans in joint space, CHOMP smooths the path, TOPP time-parameterizes it, and FK verifies the final endpoint within tolerance. Follow-up: promote to 6-DOF pose/orientation plus nonzero obstacle callbacks.
- ROBO-11: DONE for Phase 1 naming mitigation. `quantum_twin.nr` is the honest alias and `twin_core.nr` remains backward compatible. Remaining: real robotics digital twin rod.
- Documentation pass: explicit `#[no_alloc]+#[deadline]` protocol for robotics rods. Even "you can't use these rods in hard-RT today" is honest.

**Phase 2 (short-term):**
- ROBO-7 P2: implement RFC-0046 Phase B. Compiler-side TYP-008 check that `transform(p, tf)` call-site frames match. **Closes Mars Climate Orbiter failure mode.**
- ROBO-4: 6-DOF Jacobian in nullspace solver.
- ROBO-5: TF tree with name-keyed lookup + time-stamped buffer + interpolation. Multi-tree (forest) support.
- ROBO-6: URDF branching topology support. xacro expansion.
- ROBO-10: WBC strict-priority stack + torque-box constraints.
- ROBO-12: DONE for Mahony 9-DOF magnetometer yaw correction. Remaining: calibration/declination helpers, high-dynamics rejection policy, and Madgwick variant.

**Phase 3 (medium-term):**
- ROBO-1: TOPP-RA (convex per-step torque/dynamics constraints).
- ROBO-2: DONE for Phase 1 multi-DOF batch wrapper. Remaining: true coupled-basis learning across DOFs.
- ROBO-3: analytical IK path for 6-DOF canonical manipulators (Puma/UR/Kuka).
- ROBO-8: full covariant CHOMP pre-conditioning.
- ROBO-9: Cartesian-space CHOMP variant.
- ROBO-13: DONE for Phase 1 static OBB-OBB + fixed-orientation translational CCD. Remaining: angular CCD and convex mesh-vs-mesh sweep.
- Annotate robotics rods with `#[no_alloc]` where possible. Document which functions are RT-safe.

**Phase 4 (v1.0+):**
- Real robot digital twin rod (sim-to-real bridge, physics-based state mirror).
- ROS2/DDS interop.

## 3.3. v1.0 release gate
Phase 1 minimum (frame-type warning + end-to-end test). Phase 2 strongly preferred (Phase B frame enforcement is the headline safety closure). Phase 3 acceptable as v1.x. Phase 4 explicit v2.x.

## 3.4. Open questions
1. RFC-0046 Phase B implementation: how does the compiler know which functions take Pose arguments? Recommendation: annotate `Pose` argument types with frame markers in fn signature; compiler propagates.
2. End-to-end test (ROBO-14): Phase 1 uses `f64_buffer.nr` plus local f64 tolerances to keep the test on real public rod APIs. Phase 2 can add `linalg.nr` assertions if the 6-DOF fixture needs vector/matrix diagnostics.
3. URDF branching (ROBO-6): full ROS xacro support or subset? Recommendation: subset (parameters + macros, no Python evaluation).

---

# Part IV — Disposition
**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
