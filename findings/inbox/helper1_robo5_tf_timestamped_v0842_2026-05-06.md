# helper1 ROBO-5 TF timestamped interpolation evidence (v0842)

## Summary

ROBO-5 Phase 1 timestamped transform lookup is implemented for the public TF rod.
The new API stores the latest two stamped poses per frame and interpolates
translation plus normalized quaternion orientation when the requested timestamp is
inside that interval.

## Files

- `stdlib/runtime/tf_rt.c`
- `stdlib/rods/tf.nr`
- `tests/features/tf_timestamped_lookup_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/README.md`

## Validation

- `.\bin\nucleor.exe build tests\features\tf_timestamped_lookup_smoke.nr -o helper1_tf_timestamped --no-cache`
- `.\target\helper1_tf_timestamped.exe`
- `bash tools/verify.sh --only "test features/tf_timestamped_lookup_smoke"`
- `git diff --check`

## Remaining Gap

This is Phase 1 only. Remaining ROBO-5 work is string-keyed frame names,
disconnected forest support, deeper history buffers, cache/lazy lookup strategy,
and hard-RT allocation protocol.
