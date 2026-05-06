# Helper1 ROBO-14 End-to-End Robotics Smoke (v0837, 2026-05-06)

## Summary

ROBO-14 Phase 1 smoke coverage is now implemented. The old blocker was real:
FK/IK/RRT/CHOMP/TOPP expose raw `double[]` pointer contracts, while Nucleor had
no public in-memory typed f64 scratch buffer to construct those arrays and read
mutated results back.

This slice adds that missing public surface and then uses it in a real
composition fixture:

- IK solves a reachable planar-arm endpoint target.
- RRT plans from start joint state to the IK solution in free space.
- CHOMP smooths the planned path with endpoints clamped.
- TOPP builds a time profile over the smoothed path length.
- FK verifies the final trajectory endpoint still matches the IK target.

## Files Added

- `stdlib/runtime/f64_buffer_rt.c`
- `stdlib/rods/f64_buffer.nr`
- `tests/features/f64_buffer_smoke.nr`
- `tests/features/robo14_end_to_end_smoke.nr`

## Files Updated

- `docs/rfcs/gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
- `docs/rfcs/v1_PUNCHLIST.md`

## Validation

Direct build/run:

```powershell
.\bin\nucleor.exe build tests\features\f64_buffer_smoke.nr -o helper1_f64_buffer_smoke --no-cache
.\target\helper1_f64_buffer_smoke.exe

.\bin\nucleor.exe build tests\features\robo14_end_to_end_smoke.nr -o helper1_robo14_end_to_end --no-cache
.\target\helper1_robo14_end_to_end.exe
```

Focused verify:

```bash
bash tools/verify.sh --only "test features/f64_buffer_smoke"
bash tools/verify.sh --only "test features/robo14_end_to_end_smoke"
```

Both focused verify runs passed their single selected fixture. The direct
executables also exited 0.

## Remaining Work

ROBO-14 is partially closed, not finished at production depth. Remaining
follow-up:

- Promote the fixture from deterministic planar arm to 6-DOF pose/orientation.
- Add nonzero collision and obstacle callbacks.
- Add dynamics-aware TOPP/TOPP-RA once the robotics timing surface supports it.
- Keep ROBO-7 frame enforcement separate; this slice does not close the Mars
  Climate Orbiter frame-mismatch class.
