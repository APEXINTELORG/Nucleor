# Nucleor Examples

Each example is a single self-contained `.nr` file that builds with the
shipped `bin/nucleor.exe`. All examples are part of the verify gate
(`tools/verify.sh`) — they're rebuilt + run on every release, and
regressions block the gate.

## Build & run

```bash
# Build any example to ./<name>.exe
bin/nucleor.exe build examples/01_hello.nr -o hello
./hello.exe

# All examples build with the same `nuc build` command — no special flags
# needed except for 07_rust_interop, which needs the rust_bridge cdylib.
```

## Index

### Tier 1 — Language tour (foundational, v0.1)

| # | File | Topic | Demonstrates |
|---|---|---|---|
| 01 | [01_hello.nr](01_hello.nr) | Hello, world | `print`, `fn main`, return code |
| 02 | [02_fib.nr](02_fib.nr) | Fibonacci | iteration, `let mut`, comparison |
| 03 | [03_structs.nr](03_structs.nr) | Struct types | record types, field access |
| 04 | [04_rods.nr](04_rods.nr) | Rod imports | `import "stdlib/rods/..."`, cross-rod calls |
| 05 | [05_quantum.nr](05_quantum.nr) | Quantum simulator | full-state simulator from `stdlib/rods/quantum.nr` (Bell state, 1024 shots) |
| 06 | [06_perf_attrs.nr](06_perf_attrs.nr) | V2 perf attributes | `@hot`, `@const_fn`, `@layout`, `@region` |
| 07 | [07_rust_interop.nr](07_rust_interop.nr) | Rust FFI | calls into `stdlib/rods/rust_bridge/` (regex, base64, hashing). Requires `cargo build --release` in that dir first. |

### Tier 2 — Numerics & domains (v0.1)

| # | File | Topic | Demonstrates |
|---|---|---|---|
| 08 | [08_linalg.nr](08_linalg.nr) | Linear algebra | matrix ops, dot products |
| 09 | [09_ode.nr](09_ode.nr) | ODE solver | RK4 over `stdlib/rods/ode.nr` |
| 10 | [10_fft.nr](10_fft.nr) | FFT | radix-2 FFT, frequency-domain ops |
| 11 | [11_pid.nr](11_pid.nr) | PID controller | control-loop simulation |
| 12 | [12_autodiff.nr](12_autodiff.nr) | Autodiff | reverse-mode gradient computation |
| 13 | [13_test_framework.nr](13_test_framework.nr) | Test harness | `assert_*` macros, test runner |

### Tier 3 — v0.2.x stdlib showcase (real end-to-end programs)

These examples post-date the v0.2.x stdlib enrichment chain
(v0.2.18–v0.2.36) and demonstrate the helper surface in production-
shaped programs. They run out of the box and accept env-var overrides
for real-data inputs.

| # | File | Topic | Helpers exercised |
|---|---|---|---|
| 14 | [14_csv_summary.nr](14_csv_summary.nr) | CSV column statistics | `env_*`, `str_lines`, `str_split`, `str_to_i64`, `str_pad_*`, `vec_min/max/range/mean/median/stddev` |
| 15 | [15_word_count.nr](15_word_count.nr) | Word-frequency counter | `str_to_lower`, `hashmap_get_or`, `hashmap_keys`, `vec_sort_i64`, `str_pad_*`, `int_to_str` |
| 16 | [16_histogram.nr](16_histogram.nr) | ASCII histogram | numeric parsing, bucketing, `vec_min/max/range/mean/median/stddev`, ASCII-bar formatter |
| 17 | [17_linecount.nr](17_linecount.nr) | `wc`-style multi-file counter | `fs_exists`, `file_read_string`, `str_lines`, per-file + TOTAL aggregation |
| 18 | [18_benchmark.nr](18_benchmark.nr) | Micro-benchmark harness | `time_wall_ns`, `time_elapsed_ms`, `vec_min/max/mean/median/stddev/percentile`, seeded RNG via `rng_seed` |

### Tier 4 — v0.3.x robotics RT showcase

Demonstrates the v0.3 RFC-0001 real-time attribute family
(`#[no_alloc, no_panic, no_dyn, deadline = N]`) all working
together on a single tight inner loop.

| # | File | Topic | RT attrs exercised |
|---|---|---|---|
| 19 | [19_rt_pid.nr](19_rt_pid.nr) | RT-annotated PID control step | `#[no_alloc]`, `#[no_panic]`, `#[no_dyn]`, `#[deadline = N]` (RFC-0001 full stack) |
| 20 | [20_rt_motor_ffi.nr](20_rt_motor_ffi.nr) | RT motor-control kernel calling marker-tagged extern fns | RFC-0001 full stack + `#[ffi_no_alloc]` / `#[ffi_no_panic]` per-extern markers (v0.3.24, intersection rule v0.3.26) |
| 21 | [21_rt_state_machine.nr](21_rt_state_machine.nr) | Bounded-recursion segment walk (state machine / trajectory accumulator pattern) | `#[no_alloc]`, `#[no_panic]`, `#[deadline = N]`, `#[max_depth = N]` (v0.3.9 RT-008 opt-out) |

### Showcase

`showcase/` contains larger programs that span multiple rods.
See `showcase/README.md` (or run `nuc summary`) for the index.

## Env-var overrides for tier-3 demos

The tier-3 demos all default to a small bundled in-source sample so
they work out of the box. To run against real data, set the matching
env var before invoking the binary:

| Example | Env var | Format |
|---|---|---|
| 14_csv_summary | `NUC_CSV_PATH` | path to a CSV with header + numeric rows |
| 15_word_count | `NUC_TEXT_PATH` | path to a UTF-8 text file |
| 16_histogram | `NUC_HIST_PATH` | path to a file with one integer per line |
| 17_linecount | `NUC_LC_FILES` | semicolon-separated list of file paths |
| 18_benchmark | `NUC_BENCH_ITERS` | iteration count per workload (default 100) |

Example:

```bash
NUC_CSV_PATH=mydata.csv ./csv_summary.exe
NUC_LC_FILES="src/main.c;src/util.c" ./linecount.exe
NUC_BENCH_ITERS=1000 ./benchmark.exe
```

## Verify gate

`tools/verify.sh` (POSIX) and `tools/verify.ps1` (Windows) rebuild
and run every example on every release. Both gates read the example
list from `tools/examples.list` (single source of truth — added
v0.2.60). New examples must:

1. Build cleanly with `bin/nucleor.exe build examples/<name>.nr`.
2. Run to completion with exit code `0` against bundled-default input.
3. Be added to `tools/examples.list`.
4. Be listed in this README index.

## Adding a new example

```bash
# Copy a tier-3 demo as scaffolding (csv_summary is a good template):
cp examples/14_csv_summary.nr examples/19_my_demo.nr

# Edit. Build:
bin/nucleor.exe build examples/19_my_demo.nr -o my_demo

# Run, confirm exit 0:
./my_demo.exe; echo "exit=$?"

# Wire into the gate — add a single line to tools/examples.list
# (one entry per line, no .nr extension):
echo "19_my_demo" >> tools/examples.list

# Verify:
bash tools/verify.sh    # should now show N+1 / N+1 with no fails

# Add a row to this README under the matching tier.
```
