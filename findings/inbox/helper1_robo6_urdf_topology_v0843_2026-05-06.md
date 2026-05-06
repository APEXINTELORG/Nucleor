# Helper1 Finding: ROBO-6 URDF Topology Phase 1

## Summary

ROBO-6 Phase 1 is implemented. URDF parent/child link metadata is no longer
ignored: the parser stores it, public rod wrappers expose topology predicates
and parent/child counts, and `urdf_to_fk_chain` now uses topology order for
serial trees while refusing branched or forest topologies that the serial FK
runtime cannot represent.

This converts the old failure mode from "silently flatten a humanoid or
branched robot into the wrong serial arm" into a queryable, fixture-backed
refusal.

## Files

- `stdlib/runtime/urdf_rt.c`
- `stdlib/rods/urdf.nr`
- `tests/features/urdf_branch_topology_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
- `docs/rfcs/v1_PUNCHLIST.md`

## Validation

- `.\bin\nucleor.exe build tests\features\urdf_branch_topology_smoke.nr -o helper1_urdf_branch --no-cache`
- `.\target\helper1_urdf_branch.exe`
- `bash tools/verify.sh --only "test features/urdf_branch_topology_smoke"`
- `bash tools/verify.sh --only "test features/urdf_smoke"`
- `git diff --check`

## Remaining Gap

This is still Phase 1. Full ROBO-6 closure needs a true branched-tree FK/runtime
surface, xacro subset expansion, and richer link/visual/collision/inertial
model handling.
