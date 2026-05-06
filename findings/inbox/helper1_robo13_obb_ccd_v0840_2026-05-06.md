# Helper1 Finding: ROBO-13 OBB-OBB Collision / CCD Phase 1

Date: 2026-05-06
Branch: `fix/helper1-qm6-mps-joint-prob-v0831`
Scope: stdlib/runtime/test/docs only

## Summary

ROBO-13 is advanced to Phase 1. The collision rod now exposes:

- `coll_obb_obb(...)`: static OBB-OBB overlap via separating-axis test.
- `coll_ccd_obb_obb(...)`: exact time-of-impact for linearly translated
  OBB centers with fixed orientations over `[0, 1]`.

The CCD path intersects the time interval induced by all 15 OBB SAT axes
(3 A axes, 3 B axes, and 9 cross axes). This is not a sample-only CCD
approximation for the fixed-orientation translational case.

## Files

- `stdlib/runtime/collision_rt.c`
- `stdlib/rods/collision.nr`
- `tests/features/collision_obb_ccd_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
- `docs/rfcs/v1_PUNCHLIST.md`

## Validation

Focused validation:

- `.\bin\nucleor.exe build tests\features\collision_obb_ccd_smoke.nr -o helper1_collision_obb_ccd --no-cache`: PASS
- `.\target\helper1_collision_obb_ccd.exe`: PASS
- `bash tools/verify.sh --only "test features/collision_obb_ccd_smoke"`: PASS
- `git diff --check`: PASS

## Remaining Gap

This closes fixed-orientation OBB overlap and translational CCD only.
Remaining ROBO-13 work is angular CCD and convex mesh-vs-mesh sweep.
