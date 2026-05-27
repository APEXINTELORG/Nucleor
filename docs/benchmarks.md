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

## Scientific Workload Numbers

Real numerical workloads users actually run. Measured by
`examples/29_scientific_benchmark.nr`. All times are median per-iteration
wall-clock nanoseconds over 20 iterations on hosted Linux x86_64
(Ubuntu 24.04, LLVM 18), -O2 compiler binary, default Nucleor optimization.

| Workload | What it does | Median per iteration | Throughput |
|---|---|---:|---:|
| `dgesv-200` | Solve 200×200 dense linear system Ax=b (Gaussian elimination + partial pivoting) | 7.02 ms | 143 solves/s |
| `dgemm-128` | 128×128 dense matrix multiply | 8.51 ms | 117 muls/s |
| `dot-1M` | Dot product of two 1M-element f64 vectors | 28.9 ms | 35 ops/s |
| `fft-1024` | 1024-point complex FFT (radix-2 Cooley-Tukey) | 107 µs | 9300 FFTs/s |
| `sort-100K` | Sort 100K i64s (qsort) | 15.9 ms | 63 sorts/s |

**What this measures.** Nucleor's bundled numerical primitives, which are
straightforward C implementations under `stdlib/runtime/{tensor_rt.c,
fft_rt.c}`. No LAPACK, BLAS, or FFTW dependency — every reported number is
Nucleor-only, reproducible from a clean checkout with just `clang` and `libm`
on the system.

**What this doesn't measure.** Comparisons against tuned vendor libraries
(LAPACK, OpenBLAS, FFTW). The Nucleor primitives are correctness-first scalar
implementations; for performance-critical scientific work, the recommended
pattern is to call into a vendor library via the existing `extern fn` surface
(see `stdlib/rods/linalg.nr` for the wrapper pattern).

**Reproduce.** From the repo root with a built `bin/nucleor`:

```bash
./bin/nucleor build examples/29_scientific_benchmark.nr -o sci_bench
./sci_bench

# Higher iteration counts for tighter confidence intervals
NUC_BENCH_ITERS=200 ./sci_bench
```

The harness uses `time_wall_ns()` for measurement and prints min, max, mean,
median, stddev, and p95 per workload. Run it on your own hardware to establish
your baseline.

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
