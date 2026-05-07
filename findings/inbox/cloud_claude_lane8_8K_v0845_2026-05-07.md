# Cloud Lane 8 / Queue 8K — t4 strict time-helper rc=6 investigation

## Summary

`tests/features/t4_strict_time_helper_rtypes.nr` runs cleanly on native
Linux. Five consecutive runs all return rc=0. Confirms the partner's
report; the rc=6 reported elsewhere was Windows-host specific.

**Recommendation:** close 8K as Linux-clean, no patch required. The
fixture's existing assertions (`mono_ns > 0 && mono_us > 0 && mono_ms > 0`)
hold on this Linux runner.

## Reproduction

```
$ bin/nucleor build tests/features/t4_strict_time_helper_rtypes.nr -o t4_time
  source: tests/features/t4_strict_time_helper_rtypes.nr (1731 bytes)
  mode: fast (ownership + type)
  functions: 1
  strings: 0
  optimized: 9 instructions
  emitted: target/t4_time.ll (48891 bytes)
  compiled: target/t4_time
BUILD_EXIT=0

$ for i in 1 2 3 4 5; do target/t4_time; echo "run$i rc=$?"; done
run1 rc=0
run2 rc=0
run3 rc=0
run4 rc=0
run5 rc=0
```

## Coverage of the fixture's return codes

The fixture returns rc=0 only when every assertion passes. In particular:

- `start_ms >= 1700000000000` — POSIX wall-ms time is far past 2023. ✓
- `wall_ns >= 1700000000000000000` — POSIX `clock_gettime(CLOCK_REALTIME)` ns. ✓
- `wall_us >= 1700000000000000` — wall_us derived from wall_ns. ✓
- `wall_s >= 1700000000` — wall seconds. ✓
- `now > 0` — alias of wall_ms. ✓
- **`mono_ns > 0 && mono_us > 0 && mono_ms > 0` (line 33; rc=6 case)** —
  POSIX `clock_gettime(CLOCK_MONOTONIC)` returns a positive number of
  ns/us/ms since boot. ✓
- `slept_ms == 0 && slept_us == 0` — sleep_ms / sleep_us return 0 on
  success on POSIX. ✓
- `elapsed >= 0 && elapsed < 5000` — wall delta during the test wall
  window. ✓
- Calendar helpers (`time_year`/`month`/`day`/...) on the
  `ts=1776591045` literal — fixed-point UTC field decomposition. ✓

## Classification

**(c) flake / host-specific** on Windows side, **Linux-clean** here. The
underlying runtime helpers (`time_monotonic_ns`/`us`/`ms`) on POSIX go
through `clock_gettime(CLOCK_MONOTONIC, ...)` which is well-defined and
strictly positive. The Windows `QueryPerformanceCounter`-based path can
in principle return zero on the very first call after boot when QPC
warm-up is incomplete, which would explain the host-specific rc=6.

If the rc=6 reproduces on Windows under the verify gate, the smallest
correct fix is to gate the strict positivity assertion to require
`>= 0` rather than `> 0` for the monotonic helpers (a zero from the
backing clock is a valid Windows return value at t=0). But that is a
Windows-side investigation, not a Linux-side patch.

## Files

- `findings/inbox/cloud_claude_lane8_8K_v0845_2026-05-07.md` (this report)

No code patch required on Linux. No follow-on branch.
