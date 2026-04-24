# Robotics stack arc (v0.2.174 → v0.2.206)

A 33-ship arc that took the standard library from "scientific
computing with no robotics" to a complete production-grade
motion-planning stack: forward + inverse kinematics (with joint
limits + singularity detection + 6-DOF orientation), four
trajectory profile families (quintic / trapezoid / S-curve / DMP)
plus time-optimal path parameterization, the full geometric
collision matrix (sphere/capsule/AABB/OBB pairs + GJK + EPA + CCD),
bounding-volume hierarchies, three RRT variants + PRM with
Dijkstra query + A*, and a URDF parser. All composable, all
gate-tested, all linked into a working integration showcase.

## TL;DR — final rod inventory

| Rod | Lines | Purpose |
|---|---:|---|
| `kinematics.nr`     | 270 | Vec3 / quaternion / Pose primitives |
| `fk_chain.nr`       | 150 | Forward kinematics for serial chains + DH constructor |
| `ik_dls.nr`         | 200 | Damped Least Squares IK (3-DOF + 6-DOF + joint limits + singularity) |
| `trajectory.nr`     | 360 | Quintic + trapezoid + S-curve + DMP + TOPP |
| `collision.nr`      | 380 | All static pairs + GJK + EPA + CCD + mesh-mesh |
| `rrt.nr`            | 360 | RRT + RRT-Connect + RRT* + goal-region + path shortcutting |
| `bvh.nr`            | 230 | Bounding-volume hierarchy for broad-phase pruning |
| `prm.nr`            | 240 | Probabilistic roadmap + Dijkstra query |
| `astar.nr`          | 150 | A* shortest-path on a generic weighted graph |
| `urdf.nr`           | 110 | URDF parser → FK chain |
| (showcase)          | 100 | `examples/showcase/robotic_arm.nr` — 8-stage end-to-end |
| **Total**           | **2550** | **10 rods + 1 showcase** |

## What shipped per ship

| Tag | Headline |
|----|----------|
| v0.2.174 | `kinematics.nr` — Vec3 dot/cross/norm/add/scale, quaternion identity/from-axis-angle/Hamilton-product/conjugate/rotate, Pose new/identity/compose/inverse/apply |
| v0.2.175 | `fk_chain.nr` — forward kinematics for serial chains; revolute / prismatic / fixed joints; numerical-Jacobian-friendly |
| v0.2.176 | `ik_dls.nr` — Damped Least Squares IK; position-only; numerical Jacobian via finite differences on FK chain |
| v0.2.177 | `trajectory.nr` — quintic (5th-order) polynomial trajectory with C² boundary conditions |
| v0.2.178 | `collision.nr` — sphere-sphere, sphere-capsule, capsule-capsule (segment-segment), AABB-AABB |
| v0.2.179 | `rrt.nr` — Rapidly-exploring Random Tree (LaValle 1998); 10% goal-biased sampling; user-supplied collision callback |
| v0.2.180 | Milestone trackers v0.5/v0.6/v0.7/v0.8 drafted (roadmap concrete through 2028) |
| v0.2.181 | `trajectory.nr` — added trapezoidal velocity profile with `v_max` / `a_max` limits and triangular fallback |
| v0.2.182 | `rrt.nr` — added path shortcutting; `fk_chain.nr` — added DH-parameter constructor |
| v0.2.183 | `collision.nr` — added GJK (Gilbert-Johnson-Keerthi) for arbitrary convex shapes via support functions |
| v0.2.184 | `bvh.nr` — bounding-volume hierarchy with overlap and self-pair queries (broad-phase pruning) |
| v0.2.185 | `prm.nr` — probabilistic roadmap (multi-query complement to RRT); build side |
| v0.2.186 | `astar.nr` — generic A* shortest-path on a weighted graph with user-supplied neighbor + heuristic callbacks |
| v0.2.187 | `examples/showcase/robotic_arm.nr` — initial end-to-end integration of 5 robotics rods |
| v0.2.188 | `rrt.nr` — added RRT-Connect (Kuffner & LaValle 2000); 5-10× faster than vanilla RRT on hard problems |
| v0.2.190 | `rrt.nr` — added RRT\* (Karaman & Frazzoli 2011); asymptotically optimal via cost-aware rewiring |
| v0.2.191 | `trajectory.nr` — S-curve (bounded-jerk) profile; 7-phase, respects v/a/j limits |
| v0.2.192 | `trajectory.nr` — DMPs (Dynamic Movement Primitives, Ijspeert 2013); learnable trajectory generalization |
| v0.2.193 | `ik_dls.nr` — per-joint min/max limits in IK solver via clamping |
| v0.2.194 | `ik_dls.nr` — 6-DOF orientation IK (`ik_dls_solve_6d`); quaternion log-map angular error |
| v0.2.195 | `collision.nr` — sphere-AABB and capsule-AABB cross-pairs |
| v0.2.196 | `collision.nr` — CCD (continuous collision detection) for swept sphere-sphere |
| v0.2.197 | `collision.nr` — sphere-OBB cross-pair (closes static collision-pair matrix) |
| v0.2.198 | `rrt.nr` — goal-region planning (sample inside `[lo, hi]` region instead of single point) |
| v0.2.199 | `ik_dls.nr` — IK singularity-detection metric (track smallest \|det(J·Jᵀ + λ²I)\| during solve) |
| v0.2.200 | `prm.nr` — Dijkstra query (multi-query against precomputed roadmap; 4 new query-side exports) |
| v0.2.201 | `collision.nr` — CCD capsule-capsule and sphere-AABB (bracket+bisect) |
| v0.2.202 | `collision.nr` — GJK EPA penetration depth + contact normal (Van den Bergen 2001) |
| v0.2.203 | `trajectory.nr` — TOPP time-optimal parameterization (forward+backward pass + corner detection + within-segment peak integration) |
| v0.2.204 | `urdf.nr` — URDF parser + `urdf_to_fk_chain` (closes v0.5 roadmap) |
| v0.2.205 | `collision.nr` — convex-mesh GJK + EPA (vertex-array entry points; closes deferred mesh-mesh item) |
| v0.2.206 | `examples/showcase/robotic_arm.nr` — 8-stage end-to-end pipeline showcase |

## Architecture decisions

### i64-everywhere FFI

All robotics rods use the same i64 FFI convention as the rest of
the stdlib: floating-point values cross the boundary as
`reinterpret_cast<i64>(double)`, and structures are heap-allocated
with i64-as-pointer handles. This keeps the boundary uniform — no
per-rod calling convention — at the cost of slightly noisier user
code (`f64_to_bits(0.5)` instead of bare `0.5`).

The convention is universal across the codebase; the user-facing
rods could add a small typed-wrapper layer (`Pose<F: Frame>` per
RFC-0003) once Nucleor has generics in v0.4.

### User-supplied callbacks for collision and graph search

`rrt_plan`, `prm_build`, `prm_query`, `astar_search` all take
function pointers for the operations that depend on the specific
robot/world model. This decouples the algorithm from any specific
representation:

- RRT (and Connect, RRT*, goal-region) can plan in any joint
  space with any collision model
- PRM works on any sampling-bounded space with a custom validity
  test; the Dijkstra query reuses the same callback
- A* operates on any graph (PRM roadmap, custom workspace mesh,
  factor graph, …) via the neighbor + heuristic callbacks
- GJK / GJK EPA take per-shape support functions for arbitrary
  convex shapes; the v0.2.205 mesh-mesh entry points cover the
  common convex-polytope case without the closure-vs-fn-pointer
  ergonomics issue

### Composition over coupling

Each rod is independently shippable and tested in isolation
(per-rod build-only or functional smoke; correctness of complex
algorithms like EPA / TOPP / URDF additionally covered by direct
C unit tests against analytical answers). The integration story
is in `examples/showcase/robotic_arm.nr` — a single 100-line
program that composes 8 rods (kinematics + fk_chain + ik_dls +
trajectory + collision + bvh + the URDF and TOPP additions) into
a working motion-planning loop.

### Numerical correctness investments

Each algorithm-heavy ship was verified against an analytical
answer before tag:

- **EPA (v0.2.202)**: face-winding invariant fixed (swap `v1 ↔ v2`
  rather than just flipping the normal) — without this the
  silhouette-edge cancellation breaks and EPA stops short. Verified
  to converge to depth = 0.5 on two unit spheres at offset 1.5.
- **TOPP (v0.2.203)**: corner detection via tangent-cosine threshold
  forces `b = 0` at non-collinear waypoints (joint velocity would
  otherwise have to step-change). Within-segment peak integration
  handles the trapezoidal/triangular structure missed by naive
  endpoint integration. Verified against three analytical cases
  (single segment, L-shape with corner stop, collinear pass-through).
- **URDF (v0.2.204)**: end-to-end FK roundtrip on a 2-DOF planar
  arm — joints parsed correctly, `urdf_to_fk_chain` produces a
  chain that places the end effector at (2, 0, 0) for the
  straight-out home configuration with two 1-meter links.
- **IK singularity (v0.2.199)**: smallest `|det(J·Jᵀ + λ²I)|`
  observed across the solve, accessible via
  `ik_get_last_singularity_metric`.

## v0.6+ follow-on

Tracked in `docs/milestones/v0.5.0.md` and v0.6/v0.7/v0.8 docs.
Robotics-adjacent items deferred:

- **Typed coordinate frames** (RFC-0003): `Pose<F: Frame>` with
  compile-time frame correctness — depends on generics in v0.4
- **URDF compile-time chain validation** (RFC-0013): every
  joint's parent frame must be the previous link's child frame
- **TOPP-RA convex-optimization formulation**: full LP per
  discretization step (vs current piecewise-linear simplification)
- **Branching-tree URDF support**: humanoid / multi-arm robots
  whose `<parent>`/`<child>` topology isn't a serial chain
- **xacro preprocessing**: `<xacro:include>` resolution
- **More CCD pairs**: capsule-vs-static-AABB, sphere-vs-OBB CCD
- **Per-region sub-quadratic Dijkstra**: heap-based PRM query
  for very large roadmaps (current is O(V²))

Each item has a clear pass/fail criterion and a defined dependency
chain back to the v0.2 ships.

## How to use the stack today

The integration example `examples/showcase/robotic_arm.nr` is the
canonical reference. From a clone:

```
nuc build examples/showcase/robotic_arm.nr -o robotic_arm
target/robotic_arm.exe
```

Output:
```
=== Nucleor Robotic Arm Showcase ===
[1] Built 3-link DH planar arm
[2] FK update with all joints = 0; tip should be at (3, 0, 0)
[3] IK solve converged in N iterations
[4] Read IK singularity metric (smaller = more singular)
[5] IK re-solved with joint-1 bounded to [0, π]
[6] TOPP solved 3-waypoint path; total_time available
[7] Sphere-sphere overlap detected at d=0.7
[8] BVH obstacle hit: end-effector sphere overlaps box
=== Showcase complete: 8 stages, full robotics stack ===
```

Each stage exercises a distinct rod composing into the next; if
any one is broken the showcase fails fast at that stage.
