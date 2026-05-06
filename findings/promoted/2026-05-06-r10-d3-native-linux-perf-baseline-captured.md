# R10-D3 closure: native Linux perf baseline captured

**Date:** 2026-05-06
**Commit:** v0.8.323 (RFC-0063 Phase 1.3)
**Status:** CLOSED — baseline captured, gap to investigate in Phase 4

## Context

R10-D3 (POSIX cold/hot perf gate prep) was integrated 2026-05-05 (commit `1a962893`) but the native Linux transcript that closes the evidence loop was missing. RFC-0063 Phase 1.3 directs capture of the first Linux-native self-build perf transcript so Track B (profile-driven performance) has a measured starting point.

## Setup

- **Host:** Linux 6.18.5 (native, not WSL)
- **Toolchain:** Ubuntu clang 18.1.3
- **Compiler binary:** `bin/nucleor` ELF 64-bit LSB pie, x86-64-v1, for GNU/Linux 3.2.0, 2,126,424 bytes
- **Source:** `compiler/nucleor_s1_compiler.nr` (canonical self-build workload, 2,138,560 bytes)
- **Tool:** `bash tools/check_perf_regression.sh --verbose`
- **Doctor preflight:** all 7 checks green (native-linux, linux-proc, required-shell-tools, clang, run-capped, baseline-and-source, native-executable, elf-proof)

## Results

```
sample cold 1: 9.050s, process_tree=286MB, cache: miss -> stored (sha=3703e76e976d, size 11 MB)
sample cold 2: 9.063s, process_tree=286MB, cache: miss -> stored (sha=3703e76e976d, size 11 MB)
sample cold 3: 8.854s, process_tree=286MB, cache: miss -> stored (sha=3703e76e976d, size 11 MB)
sample hot 1: 0.510s, process_tree=17MB, cache: hit (sha=3703e76e976d, size 11 MB)
sample hot 2: 0.445s, process_tree=17MB, cache: hit (sha=3703e76e976d, size 11 MB)
sample hot 3: 0.461s, process_tree=17MB, cache: hit (sha=3703e76e976d, size 11 MB)
```

| Metric | Linux median | Windows v0.8.317 baseline | Linux/Windows ratio |
|---|---|---|---|
| Cold self-build | **9.05s** | 3.73s | **2.4x slower** |
| Hot self-build | **0.47s** | 0.26s | 1.8x slower |
| Cold process-tree RSS | **286 MB** | 308 MB | 0.93x (better) |
| Hot process-tree RSS | **17 MB** | 31 MB | 0.55x (better) |

## Findings

1. **Linux cold path is 2.4x slower than Windows** despite identical compiler binary (modulo platform target triple). Hot path is only 1.8x slower, and memory is consistently better on Linux.

2. **Gap is concentrated in cold-path build steps** — likely fopen / fork / exec / clang invocation overhead on Linux's glibc + ld-linux dynamic loader path vs the Windows toolchain in the v0.8.317 measurement. Possible factors:
   - clang invocation latency (multiple clang spawns during self-build)
   - dynamic linker resolution on each child process
   - Linux page-cache cold state vs Windows file-system caching

3. **Memory is unambiguously better on Linux** — process-tree RSS is lower in both cold and hot paths. Suggests the Linux malloc / page-cache behavior is more efficient than Windows' equivalent.

4. **Hot path is production-viable on Linux today** — 0.47s with 17 MB RSS is well under any user-perceptible threshold. The cold-path gap is what to attack.

## Baseline locked

`tools/perf_baseline_linux.json` created with:
- `cold_self_build_seconds = 9.05` (max 10.0 ceiling)
- `hot_self_build_seconds = 0.47` (max 1.0 ceiling)
- `cold_process_tree_peak_memory_mb = 286` (max 350)
- `hot_process_tree_peak_memory_mb = 17` (max 64)

Linux runs of `tools/check_perf_regression.sh` should pass `--baseline tools/perf_baseline_linux.json` until a platform-aware default is wired into the script.

## Phase 4 targets

Per RFC-0063 Phase 4, the Linux cold path is the primary target for:
- **Phase 4.1** flame-graph capture (likely surfaces the clang-invocation overhead)
- **Phase 4.2** `#[inline]` for hot helpers (mostly addresses hot, not cold)
- **Phase 4.3** per-arch SIMD (helps both)
- **Phase 4.4** LTO build of `bin/nucleor` (helps both)
- **Phase 4.5** PGO trained on the canonical workload (helps both)

**Aspirational v1.0 target:** Linux cold ≤ 5.0s (close to half the gap), Linux hot ≤ 0.35s.

## Cross-references

- RFC-0063 Phase 1.3 (this ship) and Phase 4 (perf maximization)
- `tools/perf_baseline.json` — Windows-native baseline (v0.8.317)
- `tools/perf_baseline_linux.json` — Linux-native baseline (this ship)
- `tools/check_perf_regression.sh` — POSIX gate (added 2026-05-05)
- `findings/inbox/main_full_verify_drift_v0827_2026-05-05.md` §4 — Rust bridge artifact gap (separate but adjacent)
