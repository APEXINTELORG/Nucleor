# Helper1 R11-D4 qsim auto-entangle Phase 2a

Status: ready-for-integration
Branch: `fix/helper1-r11-qsim-auto-entangle-v0828`
Base: `5ec86d7e4d965359348d33826553659157d16016`

## Scope

Implemented the Phase 2a stdlib/test/docs slice only.

- `stdlib/rods/quantum.nr` now imports `qsim_graph.nr`.
- `qsim_cnot`, `qsim_cz`, and `qsim_crk` now call `qsim_entangle_register(ctrl, tgt)` in the same semantic places their trace hooks declare entanglement.
- `qsim_ccx` now calls `qsim_entangle_register(c1, tgt)` and `qsim_entangle_register(c2, tgt)`.
- `qsim_swap` was left structurally unchanged; it inherits registration through the existing three-CNOT decomposition.
- `stdlib/rods/qsim_graph.nr` limitations text now says Phase 2a auto-entangle is wired, while raw gate-DAG auto-recording and process-local thread-safety remain open.
- `docs/rfcs/v1_PUNCHLIST.md` records R11-D4 Phase 2a as done and keeps the two remaining gaps explicit.
- Added `tests/features/qsim_graph_auto_entangle_smoke.nr`.

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
git diff --check
```

`tools/check_compiler_drift.sh` was not run because this slice did not touch compiler, bootstrap, bin, or rod manifest plumbing.

## Caveat

The focused build still emits the existing compiler informational disclosure `QM-89-ROBO-8`, whose prose says `qsim_cnot` does not wire into the queryable qsim_graph union-find. That text is now stale for the Phase 2a stdlib gate wrappers, but it lives outside this assignment's allowed scope because updating it requires compiler diagnostic changes. Main should schedule a small compiler-doc diagnostic text cleanup after integrating this stdlib slice.
