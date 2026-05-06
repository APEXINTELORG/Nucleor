# Helper1 QM-3 -- MPS Named Gate Status Sync (v0850, 2026-05-06)

## Status

QM-3 was already code-complete in this branch, but the canonical quantum RFC
still described it as open. This slice updates the docs to match the shipped
surface rather than adding duplicate wrappers.

## Evidence in tree

- `stdlib/rods/mps.nr` exposes:
  - `mps_h`, `mps_x`, `mps_z`, `mps_rz`, `mps_rx`, `mps_cnot`
  - `mps_gate_h`, `mps_gate_cnot`, `mps_gate_x`, `mps_gate_z`,
    `mps_gate_rz`, `mps_gate_rx`
  - `mps_gate_type_supported`
  - `mps_gate_from_kind`, `mps_gate_kind_supported`, `mps_gate_kind`
- `tests/features/mps_named_gate_wrappers_smoke.nr` locks the named wrapper
  and supported-code surface.
- `tests/features/quantum_gate_constants_smoke.nr` locks cross-rod shared
  gate constants and logical-kind mapping.

## Docs updated

- `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/v1_PUNCHLIST.md`

## Remaining QM-3 scope

- The raw `mps_gate(...)` integer escape hatch remains public for compatibility.
- Missing MPS runtime gates still need future dispatch: Y, S, T, RY, CZ, SWAP,
  Toffoli, and controlled rotations.
