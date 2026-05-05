# Helper2 Assignment v0822 — R10-D3 POSIX Perf Gate Prep

Date: 2026-05-05
Owner: helper2
Base: fetch current `origin/main`; merge-base with `origin/main` must equal fetched `origin/main`
Branch: `probe/helper2-r10-d3-posix-perf-gate-prep-v0822`
Mode: focused tooling prep; no compiler/runtime changes

## Objective

Use the completed R10-D3 audit report to prepare the POSIX cold/hot perf gate
implementation. The target is a reviewable branch that adds the missing POSIX
gate shape without claiming native Linux closure unless native Linux evidence
actually exists.

Prior report:

`findings/inbox/r10_d3_posix_perf_repro_parity_audit_2026-05-05.md`

Fresh deliverable report:

`findings/inbox/helper2_r10_d3_posix_perf_gate_prep_v0822_2026-05-05.md`

Do not edit or replace the older v0821 assignment file. Treat this as the
fresh current assignment.

## Allowed Write Scope

Allowed if the implementation stays clean and small:

- `tools/check_perf_regression.sh`
- `tools/verify.sh`
- `tools/verify_fast.sh` only if the fast gate intentionally mirrors this
  surface
- `tools/VERIFY_TIMING_RECIPE.md`
- the fresh findings report listed above

Do not edit:

- `compiler/`
- `stdlib/runtime/`
- `stdlib/rods/`
- `bin/`
- `bootstrap/`
- `tools/perf_baseline.json` unless real native Linux measurements justify a
  separate follow-up
- `CHANGELOG.md`
- `RELEASES.md`

## Implementation Shape

Add `tools/check_perf_regression.sh` as a POSIX/Linux counterpart to the
Windows `tools/check_perf_regression.ps1`, but make it fail closed or skip with
an explicit unsupported message when the host cannot provide valid evidence.

Minimum behavior:

- Require Linux `/proc`, `setsid`, `bash`, `clang`/native build dependencies,
  and a native POSIX `bin/nucleor` or a clearly documented bootstrap step.
- Refuse to treat WSL interop running `bin/nucleor.exe` as POSIX RSS proof.
- Reuse `tools/run_capped.sh`; do not create a second RSS sampler.
- Run cold/hot self-build samples with cache miss/hit checks.
- Compare timing and memory to `tools/perf_baseline.json` only when the
  required fields are available and the host is valid.
- Print a concise PASS/FAIL line similar to the Windows gate.
- Exit nonzero on threshold miss.

If a clean implementation is too large for one branch, stop after a findings
report that names the exact blocked pieces and the smallest next patch.

## Guardrails

- No Python helpers.
- No native Linux claims from WSL Windows `.exe` interop.
- No broad refactors.
- Keep cold compile overhead low; this gate should measure performance, not
  add avoidable work to normal builds.
- Keep memory accounting explicit: process-tree RSS and compiler-only RSS are
  different numbers.

## Suggested Commands

```powershell
git fetch origin
git checkout -b probe/helper2-r10-d3-posix-perf-gate-prep-v0822 origin/main
git merge-base HEAD origin/main
git status --short
```

Syntax and local Windows validation:

```powershell
bash -n tools/check_perf_regression.sh tools/verify.sh tools/verify_fast.sh
git diff --check
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Native Linux validation, only on a real Linux host:

```bash
bash tools/bootstrap_linux.sh
file bin/nucleor
bash tools/check_self_host_md5.sh
bash tools/check_perf_regression.sh --baseline tools/perf_baseline.json --cold-samples 3 --hot-samples 3
```

## Required Report Sections

- Summary
- Base and branch
- Files changed
- Commands run
- Unsupported-host behavior
- Native Linux evidence, or explicit note that none was available
- Perf/memory overhead notes
- Follow-up required before R10-D3 can be marked closed

