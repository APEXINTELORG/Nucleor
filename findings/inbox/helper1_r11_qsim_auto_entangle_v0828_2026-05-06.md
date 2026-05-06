# Helper1 R11-D4 qsim graph wrapper closure

Status: ready-for-integration
Branch: `fix/helper1-r11-qsim-auto-entangle-v0828`
Base: `5ec86d7e4d965359348d33826553659157d16016`

## Scope

Implemented the R11-D4 stdlib/test/docs slice only.

- `stdlib/rods/quantum.nr` now imports `qsim_graph.nr`.
- `qsim_cnot`, `qsim_cz`, and `qsim_crk` now call `qsim_entangle_register(ctrl, tgt)` in the same semantic places their trace hooks declare entanglement.
- `qsim_ccx` now calls `qsim_entangle_register(c1, tgt)` and `qsim_entangle_register(c2, tgt)`.
- `qsim_cnot`, `qsim_cz`, and `qsim_crk` now call `qsim_gate_record_checked(name, ctrl, tgt)` after the wrapped operation.
- `qsim_ccx` records two checked control-target relationships because the current public checked-record API is two-qubit.
- `qsim_swap` was left structurally unchanged; it inherits entanglement and DAG recording through the existing three-CNOT decomposition.
- `stdlib/rods/qsim_graph.nr` limitations text now says Phase 2a auto-entangle and Phase 2b auto-record are wired, while process-local thread-safety remains open.
- `docs/rfcs/v1_PUNCHLIST.md` records R11-D4 Phase 2a and Phase 2b as done and keeps the remaining thread-safety gap explicit.
- `docs/graph-capabilities.md` documents the public qsim graph contract: auto-entangle, auto-record, checked status codes, CCX's two-edge representation, and remaining process-local/thread-safety limits.
- Added `tests/features/qsim_graph_auto_entangle_smoke.nr`.
- Added `tests/features/qsim_graph_auto_record_smoke.nr`.

No edits were made to `compiler/`, `bin/`, `bootstrap/`, Python helpers, `tools/verify*`, or `tools/check_perf_regression*`.

## Validation

Passed:

```text
.\bin\nucleor.exe build tests\features\qsim_graph_auto_entangle_smoke.nr -o target\_qsim_auto_entangle --no-cache
.\target\_qsim_auto_entangle.exe
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_entangle_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_checked_record_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/quantum_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_status_disclosure_smoke"
.\bin\nucleor.exe build tests\features\qsim_graph_auto_record_smoke.nr -o target\_qsim_auto_record --no-cache
.\target\_qsim_auto_record.exe
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_record_smoke"
git diff --check
```

`tools/check_compiler_drift.sh` was not run because this slice did not touch compiler, bootstrap, bin, or rod manifest plumbing.

## Residual R11-D4 Risk

- `qsim_graph` state remains process-local and not thread-safe across pthread/async boundaries.
- CCX DAG recording is intentionally represented as two control-target records; a single-node 3-qubit DAG record would require widening the public API or adding another wrapper.
- Raw `qsim_gate_record` remains available and still returns raw `-1`; adopter code should prefer `qsim_gate_record_checked`.
- Existing boundary coverage already covers out-of-range and DAG-full behavior in `tests/features/qsim_graph_checked_record_smoke.nr`; no new boundary fixture was needed for Scope C.

## Caveat

The focused build still emits the existing compiler informational disclosure `QM-89-ROBO-8`, whose prose says `qsim_cnot` does not wire into the queryable qsim_graph union-find and that Phase 2b will add wired trackers / overflow signal. That text is now stale for the stdlib gate wrappers and checked-record path, but it lives outside this assignment's allowed scope because updating it requires compiler diagnostic changes. Main should schedule a small compiler diagnostic text cleanup after integrating this stdlib slice.
