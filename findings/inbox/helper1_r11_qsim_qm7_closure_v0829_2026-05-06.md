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

## Scope G - QM-8/QM-9 qsim graph query ergonomics

Implemented as a focused fixture:

- `tests/features/qsim_graph_query_contract_smoke.nr`

The fixture locks direct and transitive query behavior through the public
qsim_graph surface after a mixed checked-record plus high-level auto-record
sequence:

- `qsim_gate_dag_parent_count`
- `qsim_gate_dag_parent_at`
- `qsim_gate_dag_depends_on`
- `qsim_gate_dag_size`
- `qsim_graph_clear`

It also verifies that `qsim_swap` exposes the inherited three-CNOT chain and
that clear/rebuild resets the parent query state. `qsim_graph_limitations()`,
`qsim_graph_status_disclosure_smoke.nr`, and `docs/rfcs/v1_PUNCHLIST.md` now
name this as the R11-D4 Phase 2e query contract.

## Scope H - QM-7 Clifford limitations/status coherence

Updated:

- `tests/features/clifford_disclosure_smoke.nr`

The disclosure smoke now matches the actual post-Surface-17 status:

- covered: reset/rebuild round-trip and rotated Surface-17 d=3
- still open: QASM/OpenQASM2 interop and published weight-enumerator parity

No Clifford runtime ABI or compiler edits were made.

## Scope I - Quantum/qsim release evidence matrix

| Area | Fixture | Command | Status | Remaining gap |
| --- | --- | --- | --- | --- |
| QM-7 Bell/GHZ | `tests/features/qm7_clifford_bell_ghz_smoke.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_bell_ghz_smoke"` | PASS 1, SKIP 1128 | No broad randomized Clifford property suite |
| QM-7 gate identities | `tests/features/qm7_clifford_gate_identities.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_gate_identities"` | PASS 1, SKIP 1128 | No broad randomized Clifford property suite |
| QM-7 [[5,1,3]] distance | `tests/features/qm7_clifford_distance_5qubit_smoke.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_distance_5qubit_smoke"` | PASS 1, SKIP 1127 | None for this fixture |
| QM-7 reset/rebuild | `tests/features/qm7_clifford_reset_rebuild_smoke.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_reset_rebuild_smoke"` | PASS 1, SKIP 1127 | None for this fixture |
| QM-7 rotated d=3 surface code | `tests/features/qm7_clifford_surface_d3_smoke.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_surface_d3_smoke"` | PASS 1, SKIP 1127 | None for distance/detectability invariant |
| QM-7 weight enumerator | none yet | `bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_weight_enumerator_smoke"` | BLOCKED | Needs new Clifford enumerator API |
| qsim graph status codes | `tests/features/qsim_graph_status_codes_smoke.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_status_codes_smoke"` | PASS 1, SKIP 1128 | Raw runtime still returns `-1`; checked wrapper decodes known causes |
| qsim checked record | `tests/features/qsim_graph_checked_record_smoke.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_checked_record_smoke"` | PASS 1, SKIP 1128 | Raw runtime ABI unchanged |
| qsim auto-entangle | `tests/features/qsim_graph_auto_entangle_smoke.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_entangle_smoke"` | PASS 1, SKIP 1127 | Process-local state is not thread-safe |
| qsim auto-record | `tests/features/qsim_graph_auto_record_smoke.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_record_smoke"` | PASS 1, SKIP 1127 | CCX represented as two two-qubit records |
| qsim lifecycle/clear | `tests/features/qsim_graph_lifecycle_auto_record_smoke.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_lifecycle_auto_record_smoke"` | PASS 1, SKIP 1127 | Process-local state is not thread-safe |
| qsim query contract | `tests/features/qsim_graph_query_contract_smoke.nr` | `bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_query_contract_smoke"` | PASS 1, SKIP 1128 | No cross-thread query contract |
| disclosure status | `tests/features/clifford_disclosure_smoke.nr`, `tests/features/qsim_graph_status_disclosure_smoke.nr` | focused verify filters for both fixtures | PASS 1, SKIP 1128 each | Compiler Tier-C info text still has stale qsim wording |

## Scope J - Quantum next-code-surface blocker table

| Blocker | Missing API or invariant | Likely files | Runtime/compiler ABI required | Focused validation after implementation |
| --- | --- | --- | --- | --- |
| QM7-WE | Published stabilizer/logical weight-enumerator parity | `stdlib/runtime/clifford_rt.c`, `stdlib/rods/clifford.nr`, new fixture | Runtime/stdlib ABI required | `bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_weight_enumerator_smoke"` |
| QM7-QASM | QASM/OpenQASM2 import/export round-trip | `stdlib/rods/clifford.nr`, likely new runtime parser/emitter surface | Runtime/stdlib ABI likely | `bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_qasm_roundtrip_smoke"` |
| QM89-DIAG | Compiler Tier-C info text still says qsim/qsim_graph are not wired even after high-level auto-entangle/auto-record wrappers | `compiler/nucleor_s1_compiler.nr`, generated seed/bin after main owns compiler edit | Compiler edit plus normal self-host promotion | Build any qsim graph auto-record fixture and assert the stale sentence is absent |
| QSIM-THREAD | qsim_graph process-local state is not thread-safe across pthread/async boundaries | `stdlib/runtime/qsim_graph_rt.c`, `stdlib/rods/qsim_graph.nr`, thread fixture | Runtime locking/thread-local design required | `bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_thread_safety_smoke"` |
| QSIM-NARY | CCX is represented as two two-qubit control-target records because public gate-record API is binary | `stdlib/runtime/qsim_graph_rt.c`, `stdlib/rods/qsim_graph.nr`, qsim fixtures | Runtime/stdlib ABI required | `bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_ccx_nary_record_smoke"` |
| QSIM-RAW-STATUS | Raw `qsim_gate_record` still returns plain `-1`; checked wrapper decodes known causes but does not change the C ABI | `stdlib/runtime/qsim_graph_rt.c`, `stdlib/rods/qsim_graph.nr` | Runtime ABI required if raw return contract changes | `bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_raw_status_smoke"` |

## Queue 3 validation

Direct builds/runs:

- `qsim_graph_query_contract_smoke.nr` build: PASS
- `target\_qsim_graph_query.exe`: PASS
- `clifford_disclosure_smoke.nr` build: PASS
- `target\_clifford_disclosure.exe`: PASS

Focused verify:

- `test features/qsim_graph_query_contract_smoke`: PASS 1, SKIP 1128
- `test features/clifford_disclosure_smoke`: PASS 1, SKIP 1128
- `test features/qsim_graph_status_disclosure_smoke`: PASS 1, SKIP 1128
- `test features/qm7_clifford_bell_ghz_smoke`: PASS 1, SKIP 1128
- `test features/qm7_clifford_gate_identities`: PASS 1, SKIP 1128
- `test features/qsim_graph_status_codes_smoke`: PASS 1, SKIP 1128
- `test features/qsim_graph_checked_record_smoke`: PASS 1, SKIP 1128
