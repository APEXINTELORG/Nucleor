# Helper1 Finding - QM-5 MPS SVD Diagnostics

**Date:** 2026-05-06
**Branch:** `fix/helper1-qm6-mps-joint-prob-v0831`
**Status:** ready for integration

## Summary

QM-5's Phase 1 caller-facing diagnostic surface is closed. The MPS
runtime now records Jacobi SVD convergence status and negative-eigenvalue
clamp counts for the most recent adjacent two-qubit gate decomposition.

New rod wrappers:

- `mps_last_svd_converged(h)`
- `mps_last_svd_sweeps(h)`
- `mps_last_svd_off_norm(h)`
- `mps_last_svd_negative_clamps(h)`
- `mps_total_svd_nonconverged(h)`
- `mps_total_svd_negative_clamps(h)`

## Evidence

`tests/features/mps_svd_diagnostics_smoke.nr` locks:

- initial/default diagnostic status before any two-qubit SVD;
- one-qubit gates not falsely reporting SVD work;
- Bell-circuit CNOT reporting convergence within the 100-sweep bound;
- off-diagonal residual remaining nonnegative and tiny;
- zero negative-eigenvalue clamps and zero nonconvergence totals for the
  stable Bell fixture;
- limitations text naming the QM-5 diagnostic surfaces.

## Residual Gap

The runtime now reports convergence/clamp status, but it does not yet
quantify truncation-error magnitude and does not hard-fail on SVD
nonconvergence. Those remain policy/accuracy follow-ups for callers that
need strict numerical guarantees.
