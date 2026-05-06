# Helper1 QM-1 -- qsim Header Compatibility (v0851, 2026-05-06)

## Status

QM-1 is closed on `fix/helper1-qm6-mps-joint-prob-v0831`.

## What changed

- `stdlib/rods/quantum.nr`
  - Added `qsim_prob(sv, q, outcome)` for 0/1 measurement probability.
  - Added `qsim_statevec(sv)` as the explicit statevector-handle surface.
  - Added `qsim_copy(sv)` as a deep copy of complex amplitude handles.
  - Updated `qsim_limitations()` to stop treating the header-advertised names
    as missing.
- `tests/features/qsim_header_compat_smoke.nr`
  - Locks `qsim_prob`, `qsim_statevec`, and independent `qsim_copy` behavior.
- Updated quantum RFC and v1 punchlist status.

## Remaining qsim statevector gaps

- Safe per-amplitude readout still needs `qsim_statevec_amplitude(sv, idx)`.
- Statevector cap remains 24 qubits by design for memory control.
- No density-matrix/noise backend in the statevector rod.
