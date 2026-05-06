# Helper1 R11 qsim/QM-7 closure v0829

Branch: `fix/helper1-r11-qsim-auto-entangle-v0828`

## Scope D - R11-D4 Phase 2d qsim graph lifecycle

Implemented as a focused fixture:

- `tests/features/qsim_graph_lifecycle_auto_record_smoke.nr`

The fixture locks:

- `qsim_graph_clear()` resets both entanglement and gate-DAG state.
- A fresh qsim run after clear starts from zero graph/DAG counts.
- `qsim_cnot`, `qsim_cz`, and `qsim_crk` each add exactly one DAG record and
  the expected entanglement relationship.
- `qsim_swap` records exactly the inherited three-CNOT sequence, with no
  wrapper-level extra record.
- `qsim_ccx` keeps the documented two control-target records on the current
  two-qubit checked-record surface.

`docs/rfcs/v1_PUNCHLIST.md` now records Phase 2d as done. No qsim runtime ABI,
compiler, bin, bootstrap, or verify-gate changes were needed.

## Scope E - QM-7 rotated surface-code d=3 evidence

Implemented as a focused fixture:

- `tests/features/qm7_clifford_surface_d3_smoke.nr`

The fixture uses the Surface-17 stabilizer/logical set from Tomita/Svore,
Physical Review A 90, 062320 (2014), Table II:
`https://harvest.aps.org/v2/journals/articles/10.1103/PhysRevA.90.062320/fulltext`

- X stabilizers: `X0 X1 X3 X4`, `X1 X2`, `X4 X5 X7 X8`, `X6 X7`
- Z stabilizers: `Z0 Z3`, `Z1 Z2 Z4 Z5`, `Z3 Z4 Z6 Z7`, `Z5 Z8`
- Logical operators: `XL = X2 X4 X6`, `ZL = Z0 Z4 Z8`

The focused fixture locks:

- `cliff_init_code(9)` plus exactly eight independent stabilizers.
- `cliff_distance(h, 1) == 3`.
- `cliff_count_errors(h) == 27` for all single-qubit Pauli errors.
- Published logical X/Z operators commute with stabilizers and are not
  detectable, while a single-qubit X error is detectable.

`docs/rfcs/v1_PUNCHLIST.md` and `stdlib/rods/clifford.nr` now record that
rotated Surface-17 d=3 evidence is closed for QM-7 Phase 2b.

## Scope F - QM-7 weight-enumerator closure probe

Filed as a real blocker, not a fake fixture. I checked:

- Public rod surface: `stdlib/rods/clifford.nr`
- Runtime implementation: `stdlib/runtime/clifford_rt.c`
- Existing fixtures:
  - `tests/features/qm7_clifford_distance_5qubit_smoke.nr`
  - `tests/features/qm7_clifford_reset_rebuild_smoke.nr`
  - `tests/features/qm7_clifford_bell_ghz_smoke.nr`
  - `tests/features/qm7_clifford_gate_identities.nr`

The available public APIs can prove distance and detectability:
`cliff_distance`, `cliff_count_errors`, `cliff_error_detectable`,
`cliff_best_d_k1`, `cliff_num_stabilizers`. They cannot emit the
stabilizer-group weight distribution, logical coset weight distribution, or a
per-weight Pauli enumerator needed to validate published weight-enumerator
parity.

Smallest credible next surface:

- `cliff_stabilizer_weight_count(h, weight) -> i64`
- `cliff_logical_weight_count(h, n_logical, weight) -> i64`
- or one structured helper that returns counts by weight for stabilizer and
  nontrivial logical normalizer classes.

Expected follow-up validation command once that API exists:

```powershell
bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_weight_enumerator_smoke"
```

## Validation

Current focused validation passed on 2026-05-06:

```powershell
.\bin\nucleor.exe build tests\features\qsim_graph_lifecycle_auto_record_smoke.nr -o target\_qsim_graph_lifecycle --no-cache
.\target\_qsim_graph_lifecycle.exe
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_lifecycle_auto_record_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_record_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_entangle_smoke"
.\bin\nucleor.exe build tests\features\qm7_clifford_surface_d3_smoke.nr -o target\_qm7_surface_d3 --no-cache
.\target\_qm7_surface_d3.exe
bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_surface_d3_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_distance_5qubit_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_reset_rebuild_smoke"
git diff --check
```

Direct builds/runs:

- `qsim_graph_lifecycle_auto_record_smoke.nr` build: PASS
- `target\_qsim_graph_lifecycle.exe`: PASS
- `qm7_clifford_surface_d3_smoke.nr` build: PASS
- `target\_qm7_surface_d3.exe`: PASS

Focused verify:

- `test features/qsim_graph_lifecycle_auto_record_smoke`: PASS 1, SKIP 1127
- `test features/qsim_graph_auto_record_smoke`: PASS 1, SKIP 1127
- `test features/qsim_graph_auto_entangle_smoke`: PASS 1, SKIP 1127
- `test features/qm7_clifford_surface_d3_smoke`: PASS 1, SKIP 1127
- `test features/qm7_clifford_distance_5qubit_smoke`: PASS 1, SKIP 1127
- `test features/qm7_clifford_reset_rebuild_smoke`: PASS 1, SKIP 1127
