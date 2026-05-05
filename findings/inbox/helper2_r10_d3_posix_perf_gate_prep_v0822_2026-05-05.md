# Helper2 R10-D3 POSIX Perf Gate Prep v0822

Date: 2026-05-05
Owner: helper2
Branch: `probe/helper2-r10-d3-posix-perf-gate-prep-v0822`
Base: `origin/main` at `8b9a3ba0f833ec2b8a59cbf104c3595a7c83b8f2`

## Summary

This branch adds the POSIX cold/hot perf gate shape requested by the R10-D3
audit without claiming native Linux closure. The new
`tools/check_perf_regression.sh` mirrors the Windows gate at the contract
level: cold/hot self-build samples, cache miss/hit enforcement, threshold
comparison against `tools/perf_baseline.json`, and process-tree RSS sampling
through `tools/run_capped.sh`.

The implementation intentionally refuses WSL and Windows `.exe` interop as
POSIX perf/RSS evidence. On unsupported hosts, the standalone script exits
`96`; the `verify.sh` wrapper maps that to an explicit `SKIP` for the new
POSIX perf step so shell-check-only hosts do not produce a false green.

R10-D3 should remain open until a real native Linux runner records a transcript
for bootstrap, self-host fixed point, and the new POSIX perf gate.

## Base and Branch

- Worktree:
  `C:\Users\JoeWe\Nucleor_OSS_helper2_r10_d3_posix_perf_gate_prep_v0822`
- Branch:
  `probe/helper2-r10-d3-posix-perf-gate-prep-v0822`
- Base at final validation time:
  `8b9a3ba0f833ec2b8a59cbf104c3595a7c83b8f2`
- Prior audit input:
  `findings/inbox/r10_d3_posix_perf_repro_parity_audit_2026-05-05.md`

## Files Changed

- `tools/check_perf_regression.sh`
  - New POSIX/Linux cold/hot perf gate prep script.
  - Requires Linux `/proc`, `setsid`, `bash`, `clang`, a native
    `bin/nucleor`, and `tools/run_capped.sh`.
  - Refuses WSL for R10-D3 perf evidence.
  - Refuses `.exe` binaries as POSIX RSS proof.
  - Runs cold samples after clearing `target/` and `.nuc_cache`.
  - Runs hot samples without cleanup.
  - Requires cold `cache: miss` and hot `cache: hit`.
  - Compares median cold/hot wall time and process-tree RSS to
    `tools/perf_baseline.json`.
  - Prints a concise `OK POSIX perf: ...` line on pass.

- `tools/verify.sh`
  - Adds `posix_perf_regression_monitor`.
  - Adds step `T1.8 POSIX perf + memory regression monitor`.
  - Maps script exit `96` to verify return code `2`, so unsupported hosts show
    `SKIP`.

- `tools/VERIFY_TIMING_RECIPE.md`
  - Documents the native Linux validation flow.
  - Documents the WSL/interop refusal.
  - Documents that POSIX prep currently enforces process-tree RSS, while
    compiler-only RSS remains a distinct Windows-only split.

- `findings/inbox/helper2_r10_d3_posix_perf_gate_prep_v0822_2026-05-05.md`
  - This report.

## Commands Run

```powershell
bash -n tools/check_perf_regression.sh tools/verify.sh tools/verify_fast.sh
```

Result: PASS.

```powershell
bash tools/check_perf_regression.sh
```

Result: expected unsupported-host refusal in the local shell:

```text
UNSUPPORTED POSIX perf: WSL is shell-check only for this gate; use a native Linux runner for R10-D3 perf/RSS evidence
exit=96
```

```powershell
bash tools/verify.sh --only "T1.8 POSIX perf + memory regression monitor"
```

Result: expected verify-level skip:

```text
UNSUPPORTED POSIX perf: WSL is shell-check only for this gate; use a native Linux runner for R10-D3 perf/RSS evidence
[ 59/1112] SKIP  T1.8 POSIX perf + memory regression monitor
PASS: 0
SKIP: 277
exit=0
```

```powershell
git diff --check
```

Result: PASS.

```powershell
bash -n tools/check_perf_regression.sh tools/verify.sh tools/verify_fast.sh
```

Result: PASS.

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Result: PASS.

Observed Windows perf output:

```text
OK perf: cold=3.72s (max 4s) | hot=0.26s (max 1s) | mem cold_tree=307/400MB cold_compiler=292/350MB hot_tree=31/128MB hot_compiler=17/64MB
```

## Unsupported-Host Behavior

The standalone script exits `96` for unsupported evidence hosts. Unsupported
cases include:

- no Linux `/proc`,
- `uname -s` is not `Linux`,
- WSL,
- missing `setsid`,
- missing `clang`,
- missing `tools/run_capped.sh`,
- missing or non-executable native `bin/nucleor`,
- attempting to use `bin/nucleor.exe` or another PE/Windows binary as POSIX
  evidence.

This is deliberate. WSL can remain useful for shell syntax checks, but R10-D3
native perf/RSS evidence must come from a native Linux compiler process tree.

## Native Linux Evidence

No native Linux evidence was available in this local Windows/WSL environment.
No Linux timing or RSS closure claim is made by this branch.

The intended native runner command sequence is:

```bash
bash tools/bootstrap_linux.sh
file bin/nucleor
bash tools/check_self_host_md5.sh
bash tools/check_perf_regression.sh \
  --baseline tools/perf_baseline.json \
  --cold-samples 3 \
  --hot-samples 3
```

The expected pass shape is:

```text
OK POSIX perf: cold=<seconds>s (max <seconds>s) | hot=<seconds>s (max <seconds>s) | mem cold_tree=<mb>/<max>MB cold_compiler=n/a hot_tree=<mb>/<max>MB hot_compiler=n/a
```

## Perf/Memory Overhead Notes

- The gate performs three cold and three hot self-builds by default.
- Cold samples remove `target/` and `.nuc_cache/` before each run.
- Hot samples run immediately after cold samples and preserve cache state.
- `tools/run_capped.sh` samples process-tree RSS at `100 ms` by default.
- The script enforces process-tree RSS only on POSIX. It reports
  compiler-only RSS as `n/a` instead of conflating it with process-tree RSS.
- `verify_fast.sh` was not wired to this gate because cold/hot self-build
  sampling is intentionally not a fast verify surface.

## Follow-Up Required Before R10-D3 Closure

- Run the new script on a real native Linux host.
- Attach the native transcript covering bootstrap, `file bin/nucleor`,
  `check_self_host_md5.sh`, and `check_perf_regression.sh`.
- Decide whether POSIX compiler-only RSS parity is required or whether
  process-tree RSS is the accepted POSIX contract.
- Only after native evidence lands should R10-D3 be marked closed in planning
  docs or release notes.
