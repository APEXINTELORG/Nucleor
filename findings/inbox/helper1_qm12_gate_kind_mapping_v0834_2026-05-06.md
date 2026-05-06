# Helper1 v0834 - QM-12 Logical Gate-Kind Mapping

Branch: `fix/helper1-qm6-mps-joint-prob-v0831`

Base: `origin/fix/main-qm7-surface-code-v0827`

## Scope

This slice closes the remaining QM-12 rotation-ID gap without changing the
native runtime dispatch ABIs.

Changes:

- Added logical `qgate_kind_*` constants in `stdlib/rods/quantum_gates.nr`.
- Added explicit rod-native mappers:
  - `qgate_kind_to_mps(kind)`
  - `qgate_kind_to_diff(kind)`
  - `qgate_kind_supported_by_mps(kind)`
  - `qgate_kind_supported_by_diff(kind)`
- Added `qgate_unsupported()` for clean unsupported status.
- Added MPS wrappers:
  - `mps_gate_from_kind(kind)`
  - `mps_gate_kind_supported(kind)`
  - `mps_gate_kind(h, kind, q0, q1, angle_bits)`
- Added diff_sim wrappers:
  - `diff_gate_from_kind(kind)`
  - `diff_gate_kind_supported(kind)`
  - `diff_gate_kind(h, kind, q0, q1, angle)`
- Extended `tests/features/quantum_gate_constants_smoke.nr` to lock:
  - shared common native H/CNOT/X/Z IDs,
  - logical gate-kind constants,
  - RZ mapping to MPS native `4` and diff_sim native `6`,
  - RX mapping to MPS native `5` and unsupported for diff_sim,
  - wrapper behavior that rejects unsupported diff_sim RX without recording a
    gate.

## Validation

Direct build/run:

```powershell
.\bin\nucleor.exe build tests\features\quantum_gate_constants_smoke.nr -o target\_qm12_gate_kind_mapping --no-cache
.\target\_qm12_gate_kind_mapping.exe
```

Result: PASS.

Focused canonical gates:

```powershell
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/quantum_gate_constants_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_named_gate_wrappers_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/diff_sim_capacity_status_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/diff_sim_f64" | tail -n 12; exit ${PIPESTATUS[0]}'
```

All four returned `PASS: 1`, `SKIP: 1151`.

## Remaining QM-12 Caveat

The native runtime dispatch tables remain separate raw ABIs for compatibility.
The new logical-kind layer prevents cross-rod callers from reusing raw rotation
integers silently.
