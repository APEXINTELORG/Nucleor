# R13-D5 POSIX RSS e-stop parity

Date: 2026-05-05
Branch: `probe/r13-d5-posix-rss-estop-v0818`
Base: `origin/main` at `5ea94cec`

## Summary

The POSIX memory-budget gate no longer has a soft `NUC_TRACE_ALLOC=1`
green path. When PowerShell is unavailable, `tools/verify.sh` and
`tools/verify_fast.sh` now call `tools/run_capped.sh`, which enforces a
Linux `/proc` process-tree RSS e-stop with `setsid` process-group
containment. Unsupported hosts fail closed instead of passing a cumulative
allocation proxy.

This branch also rejects WSL Windows `.exe` interop for POSIX RSS evidence.
Linux `/proc` sees the WSL bridge process rather than the real Windows
compiler and `clang` process tree, so accepting that measurement would create
a false 2 MB green result. Windows `.exe` builds must use the existing
PowerShell sampler; native Linux builds can use `tools/run_capped.sh`.

## Files changed

- `tools/run_capped.sh` - new Linux `/proc` process-tree RSS e-stop wrapper.
- `tools/verify.sh` - memory-budget steps call the wrapper when no PowerShell
  sampler is selected; `NUC_TRACE_ALLOC` fallback removed.
- `tools/verify_fast.sh` - same memory-budget behavior as `verify.sh`.
- `tools/VERIFY_TIMING_RECIPE.md` - documents POSIX RSS use, exit codes, and
  WSL `.exe` rejection.
- `docs/rfcs/v1_PUNCHLIST.md` - marks R13-D5 ready on this branch.

## Validation

```text
bash -n tools/run_capped.sh tools/verify.sh tools/verify_fast.sh
PASS
```

```text
bash tools/run_capped.sh --budget-mb 1 --label estop-smoke -- sleep 2
exit=99
RSS-CAP summary: estop-smoke: KILLED peak=2 MB / 1 MB pids=1
```

```text
bash tools/run_capped.sh --budget-mb 512 --label wsl-exe-reject -- ./bin/nucleor.exe --version
exit=96
UNSUPPORTED: WSL cannot measure Windows .exe RSS through Linux /proc; use the PowerShell sampler or a native Linux compiler binary
```

```text
bash -c 'NUC_VERIFY_FORCE_POSIX_RSS=1 NUC_VERIFY_RSS_SAMPLE_MS=100 bash tools/verify.sh --only "self-host memory budget (<= 770 MB; tight cap, see docs/milestones/MEMORY_DRIFT_2026-05-01.md)"'
exit=1
FAIL self-host memory budget
ERROR: no supported real process-tree RSS e-stop is available for self-host; refusing soft-green NUC_TRACE_ALLOC fallback.
```

```text
bash tools/verify.sh --only "self-host memory budget (<= 770 MB; tight cap, see docs/milestones/MEMORY_DRIFT_2026-05-01.md)"
PASS
OK: compiler/nucleor_s1_compiler.nr peak 282 MB / 770 MB e-stop, wall 3.468s
```

```text
bash tools/verify.sh --only "tools-suite memory budget (<= 580 MB; tight cap, see docs/milestones/MEMORY_DRIFT_2026-05-01.md)"
PASS
OK: compiler/nucleor_tools_suite.nr peak 193 MB / 580 MB e-stop, wall 2.072s
```

## Notes

- No Python helper or Python runtime dependency was added.
- No compiler source, bootstrap seed, binary, perf baseline, changelog, or
  release file was touched.
- A native Linux compiler binary is still needed to validate a real Nucleor
  compile under the POSIX `/proc` RSS sampler. This branch makes unsupported
  environments fail closed until that runner exists.
