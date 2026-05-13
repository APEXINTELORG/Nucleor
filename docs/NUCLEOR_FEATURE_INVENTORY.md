# Nucleor Feature Inventory

**Version:** 1.1.0
**Date:** 2026-05-12

This inventory summarizes the shipped language, compiler, runtime, and
standard-library surface. It is intentionally concise; the language reference is
the normative user document.

## Language Core

- Self-hosted compiler written in Nucleor.
- LLVM textual IR backend linked through `clang`.
- Functions, extern functions, structs, enums, traits, impls, type aliases,
  imports, constants, statics, and attributes.
- Static type checking with explicit parameter annotations.
- Generic functions, structs, and enums.
- Where clauses and multi-trait bounds.
- Closures, including captured closures.
- Pattern matching with enum variants, literals, ranges, guards, captures,
  slices, and struct destructuring.
- `Result`, `Option`, and postfix `?` propagation.
- Module imports through string paths.
- C FFI through `extern fn`, `#cfile`, `#link`, and `#libpath`.

## Safety

- Move checking and use-after-move diagnostics.
- Heap-backed use-after-drop diagnostics.
- Conditional-move tracking.
- Definite-assignment flow analysis.
- Borrow/lifetime checks for returned or stored references.
- Heap-alias checks for `Vec<&T>` and hashmap rehash hazards.
- Sendable propagation for spawned boundaries.
- FFI null and direct-FFI diagnostics.
- Unsafe-block annotation checks.
- Effect-row checking for allocation, panic, dynamic dispatch, and FFI effects.
- Runtime contracts through `#[require]`, `#[ensure]`, and `#[invariant]`.
- Deadline and max-depth checks for real-time oriented code.

## Numeric And Scientific Surface

- Integer and floating-point literals with width suffixes.
- Strict integer arithmetic by default.
- Explicit wrapping, saturating, and checked arithmetic blocks.
- Typed SI units across common physical dimensions.
- Complex numbers.
- Linear algebra helpers including decomposition and solver rods.
- FFT, statistics, signal-processing, ODE/PDE, Bayesian, and MCMC rods.
- Robotics, planning, control, geometry, and state-estimation rods.
- Quantum simulation rods with state-vector and graph helper surfaces.
- ML-oriented helper rods, including scheduling, tensor metadata, and graph
  neural-network helpers.

## Compiler Pipeline

1. Lexer
2. Parser
3. AST arena
4. Type checker
5. Ownership, borrow, lifetime, and effect checks
6. Lowering to internal IR
7. Constant folding, copy propagation, dead-code elimination, dead-store
   elimination, and common-subexpression elimination
8. LLVM IR emission
9. Native link through `clang`

## Runtime And ABI

- Runtime C helpers live under `stdlib/runtime/`.
- Safe Nucleor wrappers live under `stdlib/rods/`.
- `Vec` and `str` use explicit runtime helpers rather than a garbage collector.
- Runtime helpers are cataloged through generated manifests used by drift gates.
- Windows release binaries are committed for bootstrap.
- Linux builds from `bootstrap/nucleor_s1_seed.ll`.

## Tooling

| Command | Purpose |
|---|---|
| `nuc init` | Scaffold a project. |
| `nuc build` | Compile a source file. |
| `nuc run` | Compile and execute. |
| `nuc test` | Build and run tests. |
| `nuc check` | Run diagnostics without native link. |
| `nuc emit` | Emit LLVM IR. |
| `nuc bench` | Benchmark repeated runs. |
| `nuc perf` | Inspect compile-path performance. |
| `nuc explain` | Explain a diagnostic code. |
| `nuc summary` | Print a compact module summary. |
| `nuc abi` | Inspect interop ABI. |
| `nuc graph` | Print source call/effect graph. |
| `nuc impact` | Print reverse call impact. |
| `nuc bootstrap status` | Report bootstrap state. |
| `nuc stage-dump` | Dump compiler stage summaries. |

## Verification Gates

- Full verifier: `tools/verify.sh`.
- Windows verifier: `tools/verify.ps1`.
- Self-host fixed point: `tools/check_self_host_md5.sh`.
- Windows performance gate: `tools/check_perf_regression.ps1`.
- Linux performance gate: `tools/check_perf_regression.sh`.
- Drift checks for helper manifests, rod manifests, releases, changelog/tag
  consistency, parser parity, and version labels.
- Mojibake/source hygiene checks.
- Rust bridge ownership harness.

## Release Snapshot

- Version: 1.1.0
- Windows verifier: `PASS=1653`, `SKIP=9`, `FAIL=0`
- Windows cold compile gate: under 4 seconds on the measured release host
- Compiler RSS ceiling: 360 MB
- Stdlib: about 290 rods
- Runtime: about 190 C source files
- Helper ABI: about 910 helper entries

## Roadmap Items

- CLI maturity work: REPL, installer behavior, command inventory parity, and
  more machine-readable output.
- Public Linux binary release artifacts.
- macOS release gating.
- Broader language-server completion and diagnostics.
- Formatter.
- Profile-guided release builds and link-time optimization.
- More aggressive SIMD specialization for selected runtime helpers.
