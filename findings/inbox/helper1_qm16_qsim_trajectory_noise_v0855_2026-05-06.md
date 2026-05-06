# Helper1 Finding - QM-16 qsim Trajectory Noise

**Date:** 2026-05-06
**Branch:** `fix/helper1-qm6-mps-joint-prob-v0831`
**Status:** ready for integration

## Summary

QM-16's Phase 1 caller-controlled statevector noise surface is closed.
`quantum.nr` now exposes explicit stochastic trajectory noise helpers:

- `qsim_noise_bit_flip(sv, q, p)` applies X with probability `p`.
- `qsim_noise_dephase(sv, q, p)` applies Z with probability `p`.
- `qsim_noise_depolarizing(sv, q, p)` applies one of X/Y/Z uniformly
  with probability `p`.

Probability validation returns stable status values:

- `qsim_noise_status_ok()` => `0`
- `qsim_noise_status_invalid_probability()` => `-1`

## Evidence

`tests/features/qsim_noise_trajectory_smoke.nr` locks deterministic
cases:

- bit-flip `p=0` leaves `|0>` unchanged;
- bit-flip `p=1` maps `|0>` to `|1>`;
- dephasing `p=0` preserves `H; H` as `|0>`;
- dephasing `p=1` maps `H; Z; H` to `|1>`;
- depolarizing `p=0` is a no-op with ok status;
- invalid probabilities return `-1`;
- `qsim_limitations()` names the QM-16 trajectory surface and the
  density-matrix limitation.

## Residual Gap

This is a pure-state trajectory approximation, not a density-matrix or
Kraus backend. Amplitude damping, phase damping, exact mixed-state
composition, and channel algebra remain future work.
