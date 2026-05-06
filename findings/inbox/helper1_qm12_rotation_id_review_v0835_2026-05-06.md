# Helper1 Finding: QM-12 Typed Rotation ID Review (v0835)

## Summary

Scope AD is already closed on the current integration base. No code change was
made for this scope.

The shared public layer is `stdlib/rods/quantum_gates.nr`. It exposes logical
gate-kind constants and explicit backend mappers:

- `qgate_kind_rz()` and `qgate_kind_rx()` are backend-neutral logical kinds.
- `qgate_kind_to_mps(kind)` maps RZ to MPS native `4` and RX to MPS native `5`.
- `qgate_kind_to_diff(kind)` maps RZ to diff_sim native `6` and returns
  `qgate_unsupported()` for RX.

This is the correct policy because MPS and diff_sim have incompatible native
rotation IDs. Forcing one raw enum would reintroduce silent cross-rod drift.

## Evidence

Existing fixture:

- `tests/features/quantum_gate_constants_smoke.nr`

Existing rods:

- `stdlib/rods/quantum_gates.nr`
- `stdlib/rods/mps.nr`
- `stdlib/rods/diff_sim.nr`

Existing docs:

- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`

## Validation

```powershell
.\bin\nucleor.exe build tests\features\quantum_gate_constants_smoke.nr -o helper1_qm12_rotation_ids --no-cache
.\target\helper1_qm12_rotation_ids.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/quantum_gate_constants_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
git diff --check
```

Result: PASS.

## Remaining Gap

Unsupported rotation families such as RY and controlled rotations are still
future gate-coverage work. They are not a rotation-ID unification blocker.
