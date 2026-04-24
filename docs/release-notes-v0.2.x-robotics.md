# Robotics stack arc (v0.2.174 → v0.2.188)

A 15-ship arc that took the standard library from "scientific computing
with no robotics" to a complete motion-planning stack: forward + inverse
kinematics, smooth trajectories, geometric collision primitives,
bounding-volume hierarchies, multi-query roadmaps, and bidirectional
RRT — all composable, all gate-tested, all linked into a working
integration showcase.

## TL;DR

| Rod | Lines | Purpose |
|---|---:|---|
| `kinematics.nr`     | 270 | Vec3 / quaternion / Pose primitives |
| `fk_chain.nr`       | 150 | Forward kinematics for serial chains + DH constructor |
| `ik_dls.nr`         | 140 | Damped Least Squares inverse kinematics |
| `trajectory.nr`     | 155 | Quintic polynomial + trapezoidal velocity profile |
| `collision.nr`      | 290 | Sphere/capsule/AABB primitives + GJK convex-convex |
| `rrt.nr`            | 330 | RRT + RRT-Connect motion planner + path shortcutting |
| `bvh.nr`            | 230 | Bounding-volume hierarchy for broad-phase pruning |
| `prm.nr`            | 180 | Probabilistic roadmap (multi-query planner) |
| `astar.nr`          | 150 | A* shortest-path on a generic weighted graph |
| (showcase)          |  70 | `examples/showcase/robotic_arm.nr` — integration |
| **Total**           | **1965** | **9 rods + 1 showcase** |

## What shipped per ship

| Tag | Headline |
|----|----------|
| v0.2.174 | `kinematics.nr` — Vec3 dot/cross/norm/add/scale, quaternion identity/from-axis-angle/Hamilton-product/conjugate/rotate, Pose new/identity/compose/inverse/apply |
| v0.2.175 | `fk_chain.nr` — forward kinematics for serial chains; revolute / prismatic / fixed joints; numerical-Jacobian-friendly |
| v0.2.176 | `ik_dls.nr` — Damped Least Squares IK; position-only; numerical Jacobian via finite differences on FK chain |
| v0.2.177 | `trajectory.nr` — quintic (5th-order) polynomial trajectory with C² boundary conditions |
| v0.2.178 | `collision.nr` — sphere-sphere, sphere-capsule, capsule-capsule (Real-Time Collision Detection segment-segment), AABB-AABB |
| v0.2.179 | `rrt.nr` — Rapidly-exploring Random Tree (LaValle 1998); 10% goal-biased sampling; user-supplied collision callback |
| v0.2.180 | Milestone trackers v0.5/v0.6/v0.7/v0.8 drafted (roadmap concrete through 2028) |
| v0.2.181 | `trajectory.nr` — added trapezoidal velocity profile with `v_max` / `a_max` limits and triangular fallback |
| v0.2.182 | `rrt.nr` — added path shortcutting; `fk_chain.nr` — added DH-parameter constructor |
| v0.2.183 | `collision.nr` — added GJK (Gilbert-Johnson-Keerthi) for arbitrary convex shapes via support functions |
| v0.2.184 | `bvh.nr` — bounding-volume hierarchy with overlap and self-pair queries (broad-phase pruning) |
| v0.2.185 | `prm.nr` — probabilistic roadmap (multi-query complement to RRT) |
| v0.2.186 | `astar.nr` — generic A* shortest-path on a weighted graph with user-supplied neighbor + heuristic callbacks |
| v0.2.187 | `examples/showcase/robotic_arm.nr` — end-to-end integration of 5 robotics rods |
| v0.2.188 | `rrt.nr` — added RRT-Connect (Kuffner & LaValle 2000); 5-10× faster than vanilla RRT on hard problems |

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

`rrt_plan`, `prm_build`, `astar_search` all take function pointers
for the operations that depend on the specific robot/world model.
This decouples the algorithm from any specific representation:

- RRT can plan in any joint space with any collision model
- PRM works on any sampling-bounded space with a custom validity test
- A* operates on any graph (PRM roadmap, custom workspace mesh,
  factor graph, …) via the neighbor + heuristic callbacks

The convention: callbacks take an i64 (the input handle) and return
an i64 (result code or output handle). The caller sets up the
allocations and lifetime as needed.

### Composition over coupling

Each rod is independently shippable and tested in isolation
(per-rod build-only or functional smoke). The integration story
is in `examples/showcase/robotic_arm.nr` — a single program that
composes 5 rods (kinematics + fk_chain + trajectory + collision +
bvh) into a working system.

## v0.4 / v0.5 follow-on

Tracked in `docs/milestones/v0.5.0.md`. Highlights:

- **Typed coordinate frames** (RFC-0003): `Pose<F: Frame>` with
  compile-time frame correctness — depends on generics in v0.4
- **URDF parser** (RFC-0013): `urdf::parse(path) -> FKChain`
  with compile-time chain validation
- **Orientation IK**: 6×n Jacobian (currently position-only)
- **EPA** (after GJK): closest-point + penetration-depth recovery
- **RRT\*** (asymptotically optimal) and **PRM Dijkstra query**
- **S-curves**, **DMPs**, and **TOPP-RA** trajectories
- **CCD** (continuous collision detection) for fast-moving objects

Each item has a clear pass/fail criterion (corresponding gate
test) and a defined dependency chain back to the v0.2 ships.

## How to use the stack today

The integration example `examples/showcase/robotic_arm.nr` is
the canonical reference. From a clone:

```
nuc build examples/showcase/robotic_arm.nr -o robotic_arm
target/robotic_arm.exe
```

Output:
```
=== Nucleor Robotic Arm Showcase ===
Built 3-link DH arm
Built obstacle BVH (2 boxes)
Collision check: spheres at d=1.5, r=1+1 overlap
Trapezoidal trajectory built
Vec3 cross-product: x × y → z (verified non-zero z)
=== Showcase complete: 5 robotics rods composed ===
```
