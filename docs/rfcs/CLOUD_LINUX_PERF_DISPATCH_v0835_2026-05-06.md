# Cloud Linux Perf Dispatch v0835

**Date:** 2026-05-06
**Audience:** Cloud Codex agent on a true native Linux host.
**Base branch:** `origin/main`

## Start Here

```bash
git fetch origin
git checkout -B cloud/linux-perf-phase4-v0835 origin/main
git merge-base HEAD origin/main
git status --short --branch
```

Do not use WSL, Wine, or Windows `.exe` interop as Linux evidence. Native Linux
means a Linux kernel, `/proc`, `clang`, and an ELF `bin/nucleor`.

## Current Linux State

R10-D3 POSIX perf evidence is closed. Do not spend the run recapturing the old
blocker unless you are establishing a new before/after optimization baseline.

Canonical evidence:

- `findings/promoted/2026-05-06-r10-d3-native-linux-perf-baseline-captured.md`
- `tools/perf_baseline_linux.json`
- `tools/check_perf_regression.sh`
- `tools/VERIFY_TIMING_RECIPE.md`

Locked Linux baseline:

- cold self-build: `9.05s`
- hot self-build: `0.47s`
- cold process-tree RSS: `286MB`
- hot process-tree RSS: `17MB`

Aspirational v1.0 target:

- Linux cold self-build <= `5.0s`
- Linux hot self-build <= `0.35s`
- no memory regression beyond `tools/perf_baseline_linux.json`

## Primary Mission

Work RFC-0063 Phase 4 Linux performance. First prove where the 9.05s cold path
goes, then make one scoped optimization if the evidence is clear.

Initial command batch:

```bash
bash tools/check_perf_regression.sh --doctor
bash tools/bootstrap_linux.sh
file bin/nucleor
bash tools/check_self_host_md5.sh
bash tools/check_perf_regression.sh \
  --baseline tools/perf_baseline_linux.json \
  --cold-samples 3 \
  --hot-samples 3 \
  --verbose
./bin/nucleor build compiler/nucleor_s1_compiler.nr -o linux_perf_probe --time-passes
```

If available on the host, add Linux-native attribution:

```bash
/usr/bin/time -v ./bin/nucleor build compiler/nucleor_s1_compiler.nr -o linux_perf_time_probe
strace -f -c ./bin/nucleor build compiler/nucleor_s1_compiler.nr -o linux_perf_strace_probe
```

Treat `strace` as optional evidence, not a required dependency.

## Candidate Work

Prefer evidence-backed changes in this order:

1. Reduce avoidable cold-path process spawning or linker invocation overhead.
2. Make `tools/check_perf_regression.sh` select `tools/perf_baseline_linux.json`
   by default on native Linux if it can do so without weakening Windows gates.
3. Evaluate LTO or PGO only as opt-in release/build modes. Do not make normal
   development cold compile slower.
4. Investigate hot helper inlining only after profiling shows compiler-side
   helper overhead rather than clang/linker process overhead.

Do not update `tools/perf_baseline_linux.json` to absorb a regression. Update
only after a measured intentional improvement and include the before/after
transcript in the report.

## Constraints

- No new Python helpers or Python requirements.
- Do not delete generated or binary artifacts to hide a dependency.
- Keep cold compile and memory overhead tight.
- Do not change Windows perf thresholds while working Linux-only evidence.
- If the host is not native Linux, stop and file a finding instead of producing
  substitute evidence.

## Required Output

Write a report under:

```text
findings/inbox/cloud_linux_perf_phase4_v0835_2026-05-06.md
```

Include:

- branch name, base SHA, head SHA;
- `uname -a`, `clang --version`, `file bin/nucleor`;
- before/after perf transcript if a patch lands;
- attribution evidence showing compiler phase vs clang/linker/process overhead;
- validation commands and exit codes;
- whether Linux cold <= `5.0s` is now realistic with this approach.

## Required Gates

For evidence-only work:

```bash
git diff --check
bash tools/check_perf_regression.sh --doctor
bash tools/check_perf_regression.sh --baseline tools/perf_baseline_linux.json --cold-samples 3 --hot-samples 3 --verbose
```

For code changes that touch compiler, runtime, bootstrap, or tooling:

```bash
git diff --check
bash tools/check_self_host_md5.sh
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
bash tools/check_perf_regression.sh --baseline tools/perf_baseline_linux.json --cold-samples 3 --hot-samples 3 --verbose
```

If a compiler source change intentionally changes the promoted compiler, follow
the repo's normal promotion path and record the new fixed-point hash.
