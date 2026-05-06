# Helper1 Assignment v0825 - QM-9 qsim Checked Gate Record Wrapper

Date: 2026-05-05
Owner: helper1
Base: fetch current `origin/main` first. At assignment creation, `origin/main` was `a37759b83d70ed7952c57c40f4a49ea600d5ed43`.
Branch: `fix/helper1-qsim-checked-record-v0825`

## Mission

Continue the QM-8/QM-9 qsim hardening lane with one small, Nucleor-only wrapper over the status preflight surface that landed in v0824.

Add a checked gate-record API in `stdlib/rods/qsim_graph.nr` so adopters do not have to call the raw `qsim_gate_record` escape hatch directly when they want structured failure behavior.

Suggested contract:

```nucleor
fn qsim_graph_status_unknown() -> i64
fn qsim_gate_record_checked(name: str, q1: i64, q2: i64) -> i64
```

Return convention:

- `>= 0`: real gate id from `qsim_gate_record`
- `-1`: `out_of_range`
- `-2`: `dag_full`
- `-3`: unknown raw failure after preflight passed

Use the existing status constants as the source of truth. Prefer `0 - qsim_graph_status_*()` in the wrapper so the negative return convention stays mechanically tied to the status codes.

## Scope

Allowed files:

- `stdlib/rods/qsim_graph.nr`
- one focused fixture under `tests/features/`
- `docs/rfcs/rod_manifest.toml` only if regeneration is required
- `docs/rfcs/v1_PUNCHLIST.md` small status/update bullet only if useful
- one report under `findings/inbox/`

Do not touch:

- compiler sources
- C runtime files
- `bin/`
- `bootstrap/`
- perf tooling
- helper2 files
- Python helpers or new Python scripts

Stop and write a finding instead of coding if this cannot be done as a clean Nucleor-side wrapper.

## Validation

Run at least:

```powershell
.\bin\nucleor.exe build tests\features\<new_fixture>.nr -o _qsim_checked_record --no-cache
.\target\_qsim_checked_record.exe
bash tools/verify.sh --only "test features/<new_fixture_name_without_nr>"
bash tools/check_compiler_drift.sh
git diff --check
```

If `check_compiler_drift.sh` fails only on unrelated tag/CHANGELOG drift, record that explicitly in the report and include the preceding manifest lines showing `rod_manifest.toml` is up to date.

## Report

Write:

`findings/inbox/helper1_qsim_checked_record_v0825_2026-05-05.md`

Include branch, base, files changed, exact return contract, validation commands, and any remaining QM-8/QM-9 gap that still needs runtime-level work.
