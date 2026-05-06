# Helper1 Finding: qsim_graph Runtime Thread Guard v0836

## Summary

The qsim graph thread-safety gap is reduced from disclosure-only to a real
runtime guard.

`stdlib/runtime/qsim_graph_rt.c` now serializes all public qsim graph entry
points with a small C11 `atomic_flag` spinlock. This protects the existing
process-local union-find arrays, active-qubit flags, gate-DAG table,
last-gate-on-qubit table, and gate-count mutations without changing the public
Nucleor ABI.

## Changed Files

- `stdlib/runtime/qsim_graph_rt.c`
- `stdlib/rods/qsim_graph.nr`
- `tests/features/qsim_graph_thread_safety_disclosure_smoke.nr`
- `tests/features/qsim_graph_thread_guard_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/graph-capabilities.md`

## Validation

```powershell
.\bin\nucleor.exe build tests\features\qsim_graph_thread_safety_disclosure_smoke.nr -o helper1_qsim_graph_thread_guard --no-cache
.\target\helper1_qsim_graph_thread_guard.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_thread_safety_disclosure_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'

.\bin\nucleor.exe build tests\features\qsim_graph_lifecycle_auto_record_smoke.nr -o helper1_qsim_graph_lifecycle_guard --no-cache
.\target\helper1_qsim_graph_lifecycle_guard.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_lifecycle_auto_record_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_query_contract_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'

.\bin\nucleor.exe build tests\features\qsim_graph_thread_guard_smoke.nr -o helper1_qsim_graph_thread_guard_parallel --no-cache
.\target\helper1_qsim_graph_thread_guard_parallel.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_thread_guard_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
```

Result: PASS.

## Remaining Gap

The runtime is now thread-safe for the existing process-local graph state, but
all users still share one global graph. The remaining scalability/design gap is
per-graph handle state so independent circuits can own independent graph
instances without global serialization.
