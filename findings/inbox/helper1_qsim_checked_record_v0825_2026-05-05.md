# Helper1 v0825 - QSIM Checked Gate Record

Date: 2026-05-05
Owner: helper1
Branch: `fix/helper1-qsim-checked-record-v0825`
Base: `5abcaa240cdf8546378cdf1bf116d71106516515` (`origin/main`)
Mode: focused QM-9 qsim hardening lane

## Summary

Added `qsim_gate_record_checked(name, q1, q2)` as a Nucleor-side checked
wrapper over the v0824 qsim gate-record preflight/status surface.

The raw `qsim_gate_record` escape hatch remains unchanged. The wrapper gives
adopters a single call that either returns a real gate id or a structured
negative status without touching compiler sources, C runtime files, bin,
bootstrap, perf tooling, or helper2 files.

## Base and branch

Commands:

```powershell
git fetch origin
git switch -c fix/helper1-qsim-checked-record-v0825 origin/main
git merge-base HEAD origin/main
```

Final merge-base before commit:

```text
5abcaa240cdf8546378cdf1bf116d71106516515
```

## Files changed

- `stdlib/rods/qsim_graph.nr`
- `tests/features/qsim_graph_checked_record_smoke.nr`
- `docs/rfcs/rod_manifest.toml`
- `docs/rfcs/v1_PUNCHLIST.md`
- `findings/inbox/helper1_qsim_checked_record_v0825_2026-05-05.md`

`docs/rfcs/rod_manifest.toml` was regenerated because the new public qsim rod
functions changed the qsim_graph function count. This is a docs manifest update
only.

## Exact return contract

New API:

```nucleor
fn qsim_graph_status_unknown() -> i64
fn qsim_gate_record_checked(name: str, q1: i64, q2: i64) -> i64
```

Return convention:

- `>= 0`: real gate id returned by `qsim_gate_record`
- `-1`: out_of_range
- `-2`: dag_full
- `-3`: unknown raw failure after preflight passed

Implementation shape:

- call `qsim_gate_record_preflight(q1, q2)` first,
- if preflight is not `ok`, return `0 - status`,
- otherwise call raw `qsim_gate_record(name, q1, q2)`,
- return the raw gate id if non-negative,
- map any unexpected raw negative return to `0 - qsim_graph_status_unknown()`.

## Fixture behavior

Added `tests/features/qsim_graph_checked_record_smoke.nr`.

It locks:

- `qsim_graph_status_unknown() == 3`,
- valid one-qubit checked record returns gate id `0`,
- valid two-qubit checked record returns gate id `1`,
- the two-qubit record depends on the first one-qubit record,
- invalid q1/q2 checked calls return `-1`,
- invalid checked calls do not mutate DAG size,
- a filled 4096-slot DAG returns `-2` for otherwise-valid checked calls,
- invalid args still return `-1` even when the DAG is full.

The `-3` unknown raw-failure path is structurally present but not directly
triggered by the fixture because the C runtime has no deterministic raw-failure
path after successful preflight other than exceptional allocation failure.

## Validation commands

Direct fixture build/run:

```powershell
.\bin\nucleor.exe build tests\features\qsim_graph_checked_record_smoke.nr -o target\_qsim_checked_record --no-cache
.\target\_qsim_checked_record.exe
```

Verify single-step:

```powershell
bash tools/verify.sh --only "test features/qsim_graph_checked_record_smoke"
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
tests/features/qsim_graph_checked_record_smoke.nr build: PASS
target/_qsim_checked_record.exe run: PASS
```

Verify single-step:

```text
bash tools/verify.sh --only "test features/qsim_graph_checked_record_smoke": PASS
PASS: 1
SKIP: 279
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

The remaining drift failure is outside this lane's write scope because the
assignment does not allow editing `CHANGELOG.md` or releases. The qsim-specific
manifest portion is clean after regenerating `rod_manifest.toml`.

## Remaining QM-8/QM-9 runtime-level work

- Raw `nuc_qsim_gate_record` still returns `-1` directly; the checked wrapper
  does not rewrite the C runtime ABI.
- qsim CNOT tracing in `quantum.nr` is still not automatically wired into the
  queryable `qsim_graph` union-find surface.
- qsim_graph remains process-local and not thread-safe across async/pthread
  boundaries.
- A future runtime-level status API could return structured status directly
  from C instead of relying on Nucleor-side preflight plus raw-return mapping.

