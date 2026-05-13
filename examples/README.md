# Nucleor Examples

Each example is a self-contained `.nr` program that builds with the shipped
compiler. The release verifier rebuilds and runs the example set so regressions
block release.

## Build And Run

```bash
bin/nucleor.exe build examples/01_hello.nr -o hello
target/hello.exe        # Windows
./target/hello          # Linux
```

Use `nuc build` or `nuc.bat build` from an installed checkout. Example
`07_rust_interop.nr` also requires building the Rust bridge under
`stdlib/rods/rust_bridge/`.

## Index

### Language Basics

| # | File | Topic | Demonstrates |
|---|---|---|---|
| 01 | [01_hello.nr](01_hello.nr) | Hello, world | `print`, `fn main`, return code |
| 02 | [02_fib.nr](02_fib.nr) | Fibonacci | iteration, mutable locals, comparison |
| 03 | [03_structs.nr](03_structs.nr) | Structs | record types and field access |
| 04 | [04_rods.nr](04_rods.nr) | Rod imports | `import "stdlib/rods/..."` |
| 05 | [05_quantum.nr](05_quantum.nr) | Quantum simulator | Bell-state simulation |
| 06 | [06_perf_attrs.nr](06_perf_attrs.nr) | Performance attributes | `@hot`, `@const_fn`, `@layout`, `@region` |
| 07 | [07_rust_interop.nr](07_rust_interop.nr) | Rust FFI | Regex, base64, and hashing through `rust_bridge` |

### Numerics And Domains

| # | File | Topic | Demonstrates |
|---|---|---|---|
| 08 | [08_linalg.nr](08_linalg.nr) | Linear algebra | matrix ops and dot products |
| 09 | [09_ode.nr](09_ode.nr) | ODE solver | RK4 over `stdlib/rods/ode.nr` |
| 10 | [10_fft.nr](10_fft.nr) | FFT | radix-2 FFT and frequency-domain ops |
| 11 | [11_pid.nr](11_pid.nr) | PID controller | control-loop simulation |
| 12 | [12_autodiff.nr](12_autodiff.nr) | Autodiff | reverse-mode gradient computation |
| 13 | [13_test_framework.nr](13_test_framework.nr) | Test harness | `assert_*` macros and test runner |

### Standard Library Programs

| # | File | Topic | Helpers exercised |
|---|---|---|---|
| 14 | [14_csv_summary.nr](14_csv_summary.nr) | CSV column statistics | env vars, string splitting, numeric parsing, vector stats |
| 15 | [15_word_count.nr](15_word_count.nr) | Word-frequency counter | text tokenization, maps, sorting, formatting |
| 16 | [16_histogram.nr](16_histogram.nr) | ASCII histogram | parsing, bucketing, vector stats, bar formatting |
| 17 | [17_linecount.nr](17_linecount.nr) | `wc`-style file counter | file IO, line counting, totals |
| 18 | [18_benchmark.nr](18_benchmark.nr) | Micro-benchmark harness | timers, seeded RNG, vector statistics |

### Real-Time And Systems

| # | File | Topic | Demonstrates |
|---|---|---|---|
| 19 | [19_rt_pid.nr](19_rt_pid.nr) | RT PID step | `#[no_alloc]`, `#[no_panic]`, `#[no_dyn]`, `#[deadline = N]` |
| 20 | [20_rt_motor_ffi.nr](20_rt_motor_ffi.nr) | Motor-control FFI | RT-safe extern calls through `#[ffi_no_alloc]` and `#[ffi_no_panic]` |
| 21 | [21_rt_state_machine.nr](21_rt_state_machine.nr) | Bounded recursion | `#[max_depth = N]` with RT attributes |
| 22 | [22_rt_export.nr](22_rt_export.nr) | C-callable kernel | `#[export]`, `#[repr(C)]`, header generation |
| 23 | [23_rt_sensor_fusion.nr](23_rt_sensor_fusion.nr) | Sensor fusion | arrays, vectors, structs, traits, casts, and inline arithmetic |
| 24 | [24_rt_kalman_step.nr](24_rt_kalman_step.nr) | Kalman-style step | nested vectors, struct math, trait methods |
| 25 | [25_patterns_tour.nr](25_patterns_tour.nr) | Pattern matching | ranges, guards, slice patterns, struct patterns, `@` bindings |
| 26 | [26_max_depth_tour.nr](26_max_depth_tour.nr) | Static recursion bound | `#[max_depth]` accepted recursion shapes |
| 27 | [27_effects_with_tour.nr](27_effects_with_tour.nr) | Function effects | `with [no_alloc, no_panic]` on function types |
| 28 | [28_isr_tour.nr](28_isr_tour.nr) | ISR attributes | `#[isr]` signature and inherited RT checks |

### Showcase

`showcase/` contains larger programs that span multiple rods. See
[showcase/README.md](showcase/README.md) for the index.

## Input Overrides

The standard-library demos default to small bundled samples. Set these
environment variables to run against your own data:

| Example | Env var | Format |
|---|---|---|
| 14_csv_summary | `NUC_CSV_PATH` | path to a CSV with header and numeric rows |
| 15_word_count | `NUC_TEXT_PATH` | path to a UTF-8 text file |
| 16_histogram | `NUC_HIST_PATH` | path to a file with one integer per line |
| 17_linecount | `NUC_LC_FILES` | semicolon-separated list of file paths |
| 18_benchmark | `NUC_BENCH_ITERS` | iteration count per workload |

## Adding An Example

1. Add `examples/<name>.nr`.
2. Confirm it builds with `nuc build examples/<name>.nr -o <name>`.
3. Confirm it runs with exit code `0`.
4. Add the basename to `tools/examples.list`.
5. Add a row to this README.
6. Run `bash tools/verify.sh --no-color -j 4`.
