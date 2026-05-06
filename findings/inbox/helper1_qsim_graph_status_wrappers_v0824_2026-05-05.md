# Helper1 v0824 - QSIM Graph Status Wrappers

Date: 2026-05-05
Owner: helper1
Branch: `fix/helper1-qsim-graph-status-wrappers-v0824`
Base: `409175e63a59e70248a7085502858661d66f45f1` (`origin/main`)
Mode: focused Tier-C quantum hardening lane

## Summary

Added a small Nucleor-side status-code preflight surface for qsim gate-DAG
recording. Adopters can now check whether a `qsim_gate_record` call is expected
to be valid, out of range, or blocked by a full 4096-slot DAG before calling the
raw record function.

The raw `qsim_gate_record` escape hatch remains unchanged. No compiler,
runtime C, bin, bootstrap, tools, changelog, release, or helper2 files were
edited.

## Base and branch

Commands:

```powershell
git fetch origin
git switch -c fix/helper1-qsim-graph-status-wrappers-v0824 origin/main
git merge-base HEAD origin/main
```

Final merge-base:

```text
409175e63a59e70248a7085502858661d66f45f1
```

## Files changed

- `stdlib/rods/qsim_graph.nr`
- `tests/features/qsim_graph_status_codes_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/rod_manifest.toml`
- `findings/inbox/helper1_qsim_graph_status_wrappers_v0824_2026-05-05.md`

`docs/rfcs/rod_manifest.toml` was regenerated because the new public rod
functions changed the qsim_graph function count. This is the minimal
drift-required docs manifest update; no compiler/generated binary artifacts
were touched.

## Status API added

New API in `stdlib/rods/qsim_graph.nr`:

```nucleor
fn qsim_graph_status_ok() -> i64
fn qsim_graph_status_out_of_range() -> i64
fn qsim_graph_status_dag_full() -> i64
fn qsim_gate_record_preflight(q1: i64, q2: i64) -> i64
```

Status codes:

- `0`: ok
- `1`: out_of_range
- `2`: dag_full

Behavior:

- `q1` must be in `[0, 1023]`.
- `q2` may be `-1` for one-qubit gates or in `[0, 1023]` for two-qubit gates.
- Invalid args return `out_of_range` before checking DAG capacity.
- Otherwise, a full DAG returns `dag_full`.
- Otherwise, preflight returns `ok`.

`qsim_graph_status_explain(q1, q2)` now uses the status-code preflight path so
the string helper and numeric helper stay aligned.

## Fixture behavior

Added `tests/features/qsim_graph_status_codes_smoke.nr`.

It locks:

- stable status constants,
- valid one-qubit preflight,
- valid two-qubit preflight,
- q1 underflow and overflow,
- q2 sentinel handling, underflow, and overflow,
- full-DAG status after recording 4096 gates,
- invalid args still winning over DAG-full status.

Existing status-disclosure smoke still builds and runs after the limitations
text update.

## Commands run

Source inspection:

```powershell
rg -n "qsim_graph_status|qsim_gate_record|qsim_graph_limitations" stdlib\rods\qsim_graph.nr tests\features
rg -n "nuc_qsim_gate_record|NUC_QSIM_MAX_GATES|NUC_QSIM_MAX_QUBITS" stdlib\runtime\qsim_graph_rt.c
```

Direct fixture build/run:

```powershell
.\bin\nucleor.exe build tests\features\qsim_graph_status_codes_smoke.nr -o target\_qsim_graph_status_codes --no-cache
.\target\_qsim_graph_status_codes.exe
```

Existing disclosure regression:

```powershell
.\bin\nucleor.exe build tests\features\qsim_graph_status_disclosure_smoke.nr -o target\helper1_v0824_qsim_status_disclosure --no-cache
.\target\helper1_v0824_qsim_status_disclosure.exe
```

Required verify step:

```powershell
bash tools/verify.sh --only "test features/qsim_graph_status_codes_smoke"
```

Manifest/drift:

```powershell
python tools/gen_rod_manifest.py
bash tools/check_compiler_drift.sh
git diff --check
```

## Validation

Direct focused fixture:

```text
tests/features/qsim_graph_status_codes_smoke.nr build: PASS
target/_qsim_graph_status_codes.exe run: PASS
```

Existing disclosure smoke:

```text
tests/features/qsim_graph_status_disclosure_smoke.nr build: PASS
target/helper1_v0824_qsim_status_disclosure.exe run: PASS
```

Verify single-step:

```text
bash tools/verify.sh --only "test features/qsim_graph_status_codes_smoke": PASS
PASS: 1
SKIP: 278
```

Drift:

```text
bash tools/check_compiler_drift.sh: FAIL
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
FAIL: git tags exist with no CHANGELOG entry:
  - v0.8.319
  - v0.8.320
  - v0.8.321
  - v0.8.322
```

The drift failure is outside this lane's write scope because the assignment
does not allow editing `CHANGELOG.md` or releases. The qsim-specific manifest
portion of the drift gate is clean after regenerating `rod_manifest.toml`.

## Remaining QM-8/QM-9 gaps

- `qsim_gate_record` still returns raw gate IDs or `-1`; the new preflight
  surface helps adopters avoid known failure causes but does not rewrite the C
  runtime ABI.
- qsim CNOT tracing in `quantum.nr` is still not automatically wired into the
  queryable `qsim_graph` union-find surface.
- `qsim_graph` remains process-local and not thread-safe across async/pthread
  boundaries.
- Phase 2b still needs the runtime-level overflow/status signal if the project
  wants structured errors from `nuc_qsim_gate_record` itself rather than
  preflight discipline.
