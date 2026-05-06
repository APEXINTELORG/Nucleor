# Helper1 Finding: ROBO-2 DMP Multi-DOF Batch Wrapper

Date: 2026-05-06
Branch: `fix/helper1-qm6-mps-joint-prob-v0831`
Scope: stdlib/runtime/test/docs only

## Summary

ROBO-2 is advanced to Phase 1. The trajectory rod now exposes a
multi-DOF DMP batch surface:

- `dmp_multi_new`
- `dmp_multi_learn`
- `dmp_multi_reset`
- `dmp_multi_step`
- `dmp_multi_free`

The implementation owns one scalar DMP per joint and accepts
sample-major `double[n_samples * n_dof]` demonstrations, plus
caller-owned `double[n_dof]` reset and output buffers. This removes
the repeated per-joint call ceremony that the robotics gap RFC flagged.
The slice also hardens the existing scalar DMP constructor for the
valid `n_basis == 1` edge case.

## Files

- `stdlib/runtime/trajectory_rt.c`
- `stdlib/rods/trajectory.nr`
- `tests/features/dmp_multi_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
- `docs/rfcs/v1_PUNCHLIST.md`

## Validation

Focused validation:

- `.\bin\nucleor.exe build tests\features\dmp_multi_smoke.nr -o helper1_dmp_multi --no-cache`: PASS
- `.\target\helper1_dmp_multi.exe`: PASS
- `bash tools/verify.sh --only "test features/dmp_multi_smoke"`: PASS
- `git diff --check`: PASS

## Remaining Gap

This is a legitimate batch wrapper, not a true coupled multi-DOF DMP
learner. Each joint still learns its own scalar forcing basis. The
remaining ROBO-2 Phase 2 work is coupled-basis learning across DOFs.
