# Helper1 Finding: ROBO-4 6D IK Nullspace Phase 1

## Summary

ROBO-4 Phase 1 is implemented. The IK rod now exposes
`ik_dls_solve_6d_nullspace`, a 6D pose-target DLS solver with a projected
posture-preference secondary task using the 6 x n Jacobian nullspace projector
`I - J+J`.

The focused smoke uses a prismatic x joint for the 6D pose task plus an
additional fixed, task-invisible joint as a redundant DOF. It proves the pose
target still solves while the redundant variable moves toward `q_pref`.

## Files

- `stdlib/runtime/ik_dls_rt.c`
- `stdlib/rods/ik_dls.nr`
- `tests/features/ik_6d_nullspace_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
- `docs/rfcs/v1_PUNCHLIST.md`

## Validation

- `.\bin\nucleor.exe build tests\features\ik_6d_nullspace_smoke.nr -o helper1_ik6d_nullspace --no-cache`
- `.\target\helper1_ik6d_nullspace.exe`
- `bash tools/verify.sh --only "test features/ik_6d_nullspace_smoke"`
- `git diff --check`

## Remaining Gap

This is Phase 1. Full ROBO-4 closure still needs a true 7-DOF manipulator
fixture with orientation + posture coupling, stronger convergence/scaling
policy, and singularity/limit-avoidance evidence.
