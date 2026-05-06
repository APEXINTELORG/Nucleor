# helper1 ROBO-8 -- CHOMP covariant preconditioner (v0845)

## Status

Phase 1 complete on helper branch `fix/helper1-qm6-mps-joint-prob-v0831`.

## What changed

- Added `nuc_chomp_optimize_covariant(...)` in `stdlib/runtime/chomp_rt.c`.
- Added public rod wrapper `chomp_optimize_covariant(...)` in
  `stdlib/rods/chomp.nr`.
- The new path preserves endpoint clamping and the existing smoothness +
  obstacle-cost model, but applies the inverse clamped-endpoint smoothness
  metric before stepping:

  `delta = A^-1 grad`

- Added `tests/features/chomp_covariant_preconditioner_smoke.nr`.

## Evidence

The smoke fixture uses a 1D zig-zag trajectory with endpoints fixed at zero.
For a smoothness-only path, the gradient is `2Aq`; one covariant step with
`alpha=0.5` should collapse the interior to zero while leaving endpoints
unchanged.

## Remaining work

- Production evidence on high-DOF manipulator trajectories.
- Obstacle-gradient evidence in narrow corridors.
- Exact signed-distance-field gradients instead of finite differences.
- Tuning guidance for `metric_reg` and `max_step`.
- Compiler informational diagnostic `QM-89-ROBO-8` still says the
  preconditioner is future work. This stdlib slice intentionally leaves
  compiler/bin/bootstrap untouched; main should clean that prose in a
  compiler-text-only follow-up.
