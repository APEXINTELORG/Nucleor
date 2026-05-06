# Helper1 Finding - QM-4 MPS SWAP Overhead Accounting

**Date:** 2026-05-06
**Branch:** `fix/helper1-qm6-mps-joint-prob-v0831`
**Status:** ready for integration

## Summary

QM-4's Nucleor-facing gap is closed for Phase 1. Non-adjacent MPS CNOT
routing now exposes deterministic SWAP-overhead accounting:

- `mps_cnot_swap_overhead(nq, ctrl, tgt)` preflights the inserted SWAP
  count for a planned CNOT.
- `mps_last_swap_overhead(h)` reports the inserted SWAP count from the
  most recent high-level MPS gate.
- `mps_total_swap_overhead(h)` accumulates inserted SWAP count for the
  MPS handle.

## Evidence

- `tests/features/mps_swap_overhead_smoke.nr` locks adjacent CNOT
  overhead as `0`, distance-3 CNOT overhead as `4`, reverse-direction
  distance-3 overhead as `4`, invalid preflight status as `-1`, total
  accumulation, and non-CNOT reset of the last-overhead counter.
- `mps_limitations()` now names the QM-4 accounting surfaces directly.

## Residual Gap

The MPS overhead is now visible to Nucleor callers but is not yet emitted
into S12b trace records. That trace integration remains the next QM-4
phase if trace-level provenance must account for compiler/transpiler
overhead separately from user-authored gates.
