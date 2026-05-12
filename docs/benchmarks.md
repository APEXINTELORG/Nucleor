# Benchmarks And Performance Gates

Nucleor treats compile-time performance as a release property. The compiler is
self-hosted, so cold self-compilation is the main regression signal.

## Current v1.1.0 Windows Gate

Measured on the local Windows release workstation:

| Metric | Result | Gate |
|---|---:|---:|
| Cold self-host compile | 3.95s | <= 4.25s |
| Hot compile | 0.12s | informational |
| Compiler RSS | 352 MB | <= 360 MB |

The full Windows verifier for the same release line completed with:

```text
PASS=1653 SKIP=9 FAIL=0
```

## Linux Correctness Gate

Hosted Ubuntu 24.04 with LLVM 18 is used for Linux correctness evidence:

- `tools/bootstrap_linux.sh`
- `tools/check_self_host_md5.sh`
- `tools/verify.sh`
- `tools/check_rust_bridge_ownership.sh`

Hosted GitHub runners are intentionally not used to lock performance baselines.
They are noisy shared VMs. Linux perf baseline locks should come from a pinned
self-hosted runner or a stable dedicated cloud VM with host details recorded in
`tools/perf_baseline_linux.json`.

## Reproducing Locally

Full verifier:

```bash
bash tools/verify.sh --no-color -j 4
```

Focused perf gate:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\check_perf_regression.ps1
```

```bash
bash tools/check_perf_regression.sh --doctor
```

## What The Numbers Mean

Nucleor emits LLVM IR and then invokes clang. For small programs, clang/link
startup often dominates. For the self-host compiler, Nucleor's own frontend,
ownership, type, lower, optimize, and emit phases are visible separately with
`--time-passes`.

`--release` asks clang for optimized native code. That can add seconds on the
self-host compiler because LLVM optimization is doing real work. Default builds
are the right comparison for edit-compile latency; release builds are the right
comparison for final binary quality.
