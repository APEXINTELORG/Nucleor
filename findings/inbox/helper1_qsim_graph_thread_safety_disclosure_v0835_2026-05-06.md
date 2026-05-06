# Helper1 Finding: qsim_graph Thread-Safety Disclosure (v0835)

Date: 2026-05-06
Branch: `fix/helper1-quantum-robotics-residuals-v0835`
Scope: Queue 7 Scope AC, qsim graph process-local thread-safety limitation

## Summary

`qsim_graph.nr` now exposes the current thread-safety contract directly:

- `qsim_graph_is_thread_safe() -> 0`
- `qsim_graph_requires_external_lock() -> 1`
- `qsim_graph_thread_safety_required_primitive() -> str`

The disclosure names the exact missing primitive: a runtime-owned qsim_graph mutex or per-graph handle state. This avoids pretending the current process-local static arrays are safe under pthread/async access.

## Files Changed

- `stdlib/rods/qsim_graph.nr`
- `tests/features/qsim_graph_thread_safety_disclosure_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`

## Validation

- `git diff --check -- stdlib\rods\qsim_graph.nr tests\features\qsim_graph_thread_safety_disclosure_smoke.nr`
- `.\bin\nucleor.exe build tests\features\qsim_graph_thread_safety_disclosure_smoke.nr -o helper1_qsim_graph_thread_safety --no-cache`
- `.\target\helper1_qsim_graph_thread_safety.exe`
- `bash tools/verify.sh --only "test features/qsim_graph_thread_safety_disclosure_smoke"`

## Residual Risk

- This is a disclosure fixture, not a synchronized runtime implementation.
- Actual closure requires either a runtime-owned lock around the static union-find/gate-DAG state or a per-graph handle-state refactor.
