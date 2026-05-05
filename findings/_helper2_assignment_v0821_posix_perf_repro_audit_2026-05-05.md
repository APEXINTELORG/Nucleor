# Helper2 Assignment - R10-D3 POSIX Perf/Repro Parity Audit

Created: 2026-05-05
Owner: helper2
Base: fetch current `origin/main` before branching

## Branch Setup

```powershell
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS fetch origin
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS worktree add `
  C:\Users\JoeWe\Nucleor_OSS_helper2_r10_d3_posix_perf_repro_audit_v0821 `
  -b probe/helper2-r10-d3-posix-perf-repro-audit-v0821 origin/main
cd C:\Users\JoeWe\Nucleor_OSS_helper2_r10_d3_posix_perf_repro_audit_v0821
git merge-base HEAD origin/main
```

The merge-base must equal fetched `origin/main`.

## Primary Task

Produce a findings-only audit for R10-D3 POSIX perf/repro parity.

Goal: document exactly what the current repo can and cannot prove on POSIX
without a native Linux runner/binary, and identify the minimal runner/evidence
needed to close the gap.

Write one report:

`findings/inbox/r10_d3_posix_perf_repro_parity_audit_2026-05-05.md`

## Required Audit Questions

1. Which verify/perf/repro commands are Windows-only today?
2. Which POSIX commands exist and parse cleanly?
3. Which commands require native Linux process evidence rather than WSL?
4. Which commands can be run under WSL as shell/script checks only?
5. What exact command should a native Linux runner execute to prove:
   - POSIX self-host reproducibility
   - POSIX cold/hot timing
   - POSIX process-tree RSS e-stop behavior
6. What files would need edits in a future implementation branch?

## WSL / Linux Rule

Do not treat WSL `/proc` as valid memory/RSS evidence for Windows
`bin\nucleor.exe`.

Reason: when WSL launches `bin/nucleor.exe`, it is launching a Windows `.exe`
through interop. Linux `/proc` sees a small bridge process, not the real
Windows `nucleor.exe`, `clang`, or `lld` process tree. Any low RSS number from
that path is false evidence.

Valid evidence split:

- Windows `.exe` memory/perf: use PowerShell tools:
  - `tools\measure_peak_build.ps1`
  - `tools\check_perf_regression.ps1`
- POSIX `/proc` memory/perf: use a native Linux Nucleor compiler binary, not
  `bin\nucleor.exe` through WSL interop.
- WSL is acceptable for shell parser checks, `bash -n`, and command-shape
  dry-runs that do not claim native RSS/process-tree proof.

## Hard Boundaries

Do not edit:

- `compiler/`
- `stdlib/runtime/`
- `stdlib/rods/`
- `bin/`
- `bootstrap/`
- `tools/perf_baseline.json`
- `CHANGELOG.md`
- `RELEASES.md`

Do not change verify/perf scripts in this assignment. If an implementation
path is obvious, document it in the finding/report and stop.

Do not add Python helpers or Python runtime dependencies.

## Suggested Evidence Commands

Use only commands that are safe in the local environment.

```powershell
git diff --check
bash -n tools/verify.sh tools/verify_fast.sh
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

If a command is intentionally not run, write why. For example, native Linux
RSS proof cannot be produced from WSL + Windows `.exe`.

No full verify is required unless you decide it adds signal; this is an audit
lane, not a release gate.

## Completion

Commit and push only the report/finding file.

```powershell
git push origin probe/helper2-r10-d3-posix-perf-repro-audit-v0821
```

Then report:

- branch
- HEAD
- merge-base
- report path
- commands run and results
- unsupported boundaries
- recommended next implementation lane
