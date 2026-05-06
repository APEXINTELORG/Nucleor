# Helper1 Finding: QM-6 Bounded MPS Statevector Range Extraction (v0835)

Date: 2026-05-06
Branch: `fix/helper1-quantum-robotics-residuals-v0835`
Scope: Queue 7 Scope AB, QM-6 high-qubit MPS readout without full-state materialization

## Summary

`mps_statevector_range(h, start_basis, count)` now materializes only a bounded computational-basis amplitude window and leaves the existing full-state `mps_statevector_max_qubits()` cap unchanged.

The runtime exposes `mps_statevector_range_max_count()` as the per-call cap and fails closed for negative indices, out-of-range windows, and count values above the cap.

## Files Changed

- `stdlib/runtime/mps_rt.c`
- `stdlib/rods/mps.nr`
- `tests/features/mps_statevector_range_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`

## Validation

- `git diff --check -- stdlib\runtime\mps_rt.c stdlib\rods\mps.nr tests\features\mps_statevector_range_smoke.nr`
- `.\bin\nucleor.exe build tests\features\mps_statevector_range_smoke.nr -o helper1_mps_statevector_range --no-cache`
- `.\target\helper1_mps_statevector_range.exe`
- `bash tools/verify.sh --only "test features/mps_statevector_range_smoke"`
- `bash tools/verify.sh --only "test features/mps_bell_probabilities_smoke"`

## Residual Risk

- This is bounded range materialization, not true external-sink/callback streaming.
- The runtime intentionally does not raise `mps_statevector_max_qubits()`.
- The i64 public ABI can address practical high-qubit windows but cannot name every basis state above the signed i64 range; the range helper fails closed for `nq > 62`.
