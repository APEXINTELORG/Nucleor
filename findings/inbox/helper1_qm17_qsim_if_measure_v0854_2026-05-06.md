# Helper1 Finding - QM-17 qsim Mid-Circuit Feedback

**Date:** 2026-05-06
**Branch:** `fix/helper1-qm6-mps-joint-prob-v0831`
**Status:** ready for integration

## Summary

QM-17's Phase 1 statevector feedback surface is closed. `quantum.nr`
now exposes `qsim_if_measure(...)`, which measures one qubit and
immediately applies a selected one-qubit feedback gate on the then/else
branch.

Feedback gate constants:

- `qsim_feedback_gate_none`
- `qsim_feedback_gate_h`
- `qsim_feedback_gate_x`
- `qsim_feedback_gate_y`
- `qsim_feedback_gate_z`
- `qsim_feedback_gate_s`
- `qsim_feedback_gate_t`
- `qsim_feedback_gate_rx`
- `qsim_feedback_gate_ry`
- `qsim_feedback_gate_rz`

## Evidence

`tests/features/qsim_if_measure_feedback_smoke.nr` locks deterministic
then/else behavior by preparing the measured qubit in basis states:

- measurement outcome `1` applies the then-branch X gate;
- measurement outcome `0` applies the else-branch X gate;
- invalid expected outcome returns `-1`;
- unsupported feedback gate code returns `-2`;
- `qsim_limitations()` names QM-17 and the feedback surface.

## Residual Gap

This is statevector execution semantics only. Hardware timing,
controller latency, and target lowering remain RFC-0054 Phase B work.
