# helper1 ROBO-1 -- TOPP diagonal torque-limit tightening (v0847)

## Status

Phase 1 complete on helper branch `fix/helper1-qm6-mps-joint-prob-v0831`.

## What changed

- Added optional per-joint diagonal inertia and torque limits to the multi-DOF
  TOPP solver in `stdlib/runtime/trajectory_rt.c`.
- Added public rod wrappers in `stdlib/rods/trajectory.nr`:
  - `topp_set_inertia`
  - `topp_set_tau_max`
  - `topp_effective_amax`
  - f64 ergonomic wrappers for the same surfaces.
- Added `tests/features/topp_torque_limit_smoke.nr`.
- Updated the robotics gap RFC, README, and v1 punchlist.

## Evidence

The smoke builds a 1-DOF path from 0 to 1 with high kinematic acceleration
(`amax = 10`) and then applies `inertia = 2`, `tau_max = 1`, which tightens
the effective acceleration to `0.5`. The torque-limited solve must take
materially longer than the kinematic-only solve.

## Remaining work

- Full coupled TOPP-RA with path-dependent torque and dynamics constraints.
- Asymmetric acceleration/torque limits.
- Non-diagonal inertia, Coriolis, and gravity terms.
