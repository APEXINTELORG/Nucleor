# Helper1 ROBO-9 -- Cartesian CHOMP Phase 1 (v0849, 2026-05-06)

## Status

ROBO-9 Phase 1 is implemented on `fix/helper1-qm6-mps-joint-prob-v0831`.

## What changed

- Added `nuc_chomp_optimize_cartesian_planar_2link(...)` in
  `stdlib/runtime/chomp_rt.c`.
- Added `nuc_chomp_cartesian_planar_2link_cost(...)` as a diagnostic
  cost helper.
- Added public rod wrappers in `stdlib/rods/chomp.nr`.
- Added `tests/features/chomp_cartesian_planar_2link_smoke.nr`.
- Updated the robotics RFC, gap README, and v1 punchlist to mark ROBO-9
  Phase 1 done while leaving generic high-DOF / SDF / obstacle-gradient
  work open.

## Technical shape

The new surface optimizes a planar two-link joint trajectory against a
desired Cartesian end-effector path:

- input path: `double[N * 2]` joint waypoints `(q1, q2)`;
- target path: `double[N * 2]` Cartesian waypoints `(x, y)`;
- endpoints are clamped;
- interior gradient is joint smoothness plus analytical Cartesian
  tracking gradient;
- FK and Jacobian are analytical for the planar two-link arm, avoiding
  callback ABI ambiguity in this Phase 1 slice.

The task-space term is:

`grad_q = w_smooth * grad_smooth + w_cart * J(q)^T * 2(FK(q) - x_target)`

## Validation

- Direct build/run:
  `.\bin\nucleor.exe build tests\features\chomp_cartesian_planar_2link_smoke.nr -o helper1_chomp_cartesian --no-cache`
  then `.\target\helper1_chomp_cartesian.exe`
  PASS.
- Focused verify:
  `bash tools/verify.sh --only "test features/chomp_cartesian_planar_2link_smoke"`
  PASS 1 / SKIP 281.
- Regression adjacent:
  `bash tools/verify.sh --only "test features/robo_limitations_smoke"`
  PASS 1 / SKIP 281.
- Regression adjacent:
  `bash tools/verify.sh --only "test features/chomp_covariant_preconditioner_smoke"`
  PASS 1 / SKIP 281.
- Hygiene:
  `git diff --check`
  PASS.

## Remaining ROBO-9 scope

- Generic high-DOF robot-model FK/Jacobian support.
- Obstacle/SDF-aware Cartesian gradients.
- Production manipulator reach-around fixture.

## Caveat

The compiler-side informational diagnostic `QM-89-ROBO-8` still carries
stale CHOMP prose from before the ROBO-8/ROBO-9 helper slices. This slice
does not edit compiler/bin/bootstrap artifacts; the runtime and public rod
documentation now reflect the new surfaces.
