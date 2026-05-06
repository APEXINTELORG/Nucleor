# helper1 ROBO-3 -- Analytical planar 2-link IK (v0848)

## Status

Phase 1 complete on helper branch `fix/helper1-qm6-mps-joint-prob-v0831`.

## What changed

- Added `nuc_ik_analytic_planar_2link(...)` in
  `stdlib/runtime/ik_dls_rt.c`.
- Added public wrapper `ik_analytic_planar_2link(...)` in
  `stdlib/rods/ik_dls.nr`.
- Added `tests/features/ik_analytic_planar_2link_smoke.nr`.
- Updated robotics gap docs and v1 punchlist.

## Evidence

The smoke solves a planar 2R arm with `l1 = l2 = 1` for target `(1, 1)`.
The elbow-positive analytical solution is `q1 ~= 0`, `q2 ~= pi/2`. The same
fixture verifies that target `(3, 0)` is refused as unreachable.

## Remaining work

- 6-DOF canonical manipulator analytical solvers (Puma/UR/Kuka class).
- Branch enumeration and branch selection API.
- Singularity classification.
- FK-backed validation fixture for every returned branch.
