# Helper1 Assignment v0824 - QSIM Graph Status Wrappers

Date: 2026-05-05
Owner: helper1
Base: fetch current `origin/main`; expected assignment issue base is `00539b910c7c96e0ea700584071ca5b390c5c70f` or newer
Branch: `fix/helper1-qsim-graph-status-wrappers-v0824`
Mode: focused Tier-C quantum hardening lane

## Objective

Advance the QM-8/QM-9 qsim graph punchlist without touching compiler or
generated artifacts.

Current state:

- `qsim_graph_status_explain(q1, q2)` can explain likely `-1` causes as text.
- `qsim_gate_record(...)` still returns raw `-1` when the DAG is full or args
  are invalid.
- The limitations text still frames the safe path as manual preflight discipline.

Your target: add a small code-status preflight surface for gate-DAG recording
so adopters can check the reason before calling `qsim_gate_record`.

Recommended API shape:

- `qsim_graph_status_ok() -> i64` returns `0`
- `qsim_graph_status_out_of_range() -> i64` returns `1`
- `qsim_graph_status_dag_full() -> i64` returns `2`
- `qsim_gate_record_preflight(q1: i64, q2: i64) -> i64`

Expected behavior:

- valid one-qubit gate args `(q1 in range, q2 = -1)` return `0`
- valid two-qubit gate args return `0`
- any qubit outside `[0, 1023]` returns `1`
- if `qsim_graph_gate_slots_remaining() <= 0`, valid args return `2`

Do not remove the raw `qsim_gate_record` escape hatch. This is a safe
preflight/status surface, not a runtime ABI rewrite.

## Allowed Write Scope

Allowed:

- `stdlib/rods/qsim_graph.nr`
- one focused smoke fixture under `tests/features/`
- `docs/rfcs/v1_PUNCHLIST.md`
- `findings/inbox/helper1_qsim_graph_status_wrappers_v0824_2026-05-05.md`

Do not edit:

- `compiler/`
- `stdlib/runtime/`
- `bin/`
- `bootstrap/`
- `tools/`
- `CHANGELOG.md`
- `RELEASES.md`
- helper2 effect/restricts files

If you prove a C runtime change is required, stop with a finding instead of
widening the patch.

## Guardrails

- No Python helpers.
- Keep the smoke small. A 4096-iteration fill loop is acceptable to prove the
  DAG-full code path; do not add large randomized tests.
- Keep wording honest: this does not auto-wire qsim CNOT entanglement into
  qsim_graph, and it does not make qsim_graph thread-safe.
- Do not touch the NN/GNN ABI repair branch files.

## Suggested Commands

```powershell
git fetch origin
git checkout -b fix/helper1-qsim-graph-status-wrappers-v0824 origin/main
git merge-base HEAD origin/main
git status --short
```

Useful searches:

```powershell
rg -n "qsim_graph_status|qsim_gate_record|qsim_graph_limitations" stdlib\rods\qsim_graph.nr tests\features
rg -n "nuc_qsim_gate_record|NUC_QSIM_MAX_GATES|NUC_QSIM_MAX_QUBITS" stdlib\runtime\qsim_graph_rt.c
```

## Required Report Sections

- Summary
- Base and branch
- Files changed
- Status API added
- Fixture behavior
- Commands run
- Validation
- Remaining QM-8/QM-9 gaps

## Validation

Required before pushing:

```powershell
.\bin\nucleor.exe build tests\features\<new_fixture>.nr -o _qsim_graph_status_codes --no-cache
target\_qsim_graph_status_codes.exe
bash tools/verify.sh --only "test features/<new_fixture_without_ext>"
bash tools/check_compiler_drift.sh
git diff --check
```

Push:

```powershell
git push -u origin fix/helper1-qsim-graph-status-wrappers-v0824
```

