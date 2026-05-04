# RFC-0048 — Hardware Capability Queries

**Status:** Draft (frontier easy-win — V2.3)
**Date:** 2026-05-03

## Motivation

Adopters writing kernels that conditionally use FP4 / FP8 / BF16 / SVE / AVX-512 / tensor cores need a way to ask "does this build target support FP4?" at COMPILE time, not at runtime via dynamic dispatch (which costs perf and code size). The frontier writeup proposes `if target.has(FP4) { ... }` as a compile-time-resolved branch.

## Design

A `target` compile-time builtin exposing a fixed set of queries:

```nucleor
if target.has(FP4)        { ... fp4_kernel(); ... }
if target.has(FP8)        { ... fp8_kernel(); ... }
if target.has(BF16)       { ... bf16_kernel(); ... }
if target.has(AVX2)       { ... avx2_kernel(); ... }
if target.has(AVX512)     { ... avx512_kernel(); ... }
if target.has(NEON)       { ... neon_kernel(); ... }
if target.has(SVE)        { ... sve_kernel(); ... }
if target.has(TENSOR_CORES) { ... tc_kernel(); ... }
if target.has(CUDA)       { ... cuda_kernel(); ... }
if target.has(VULKAN)     { ... vulkan_kernel(); ... }
if target.os(WINDOWS)     { ... win_path(); ... }
if target.os(LINUX)       { ... linux_path(); ... }
if target.arch(X86_64)    { ... x86_path(); ... }
if target.arch(AARCH64)   { ... arm_path(); ... }
```

`target.has(X)` returns a compile-time `bool` resolved at build time per target manifest. The dead branch is DCE'd — adopters get zero runtime overhead.

## Implementation

- **Parser:** `target.has(X)` and `target.os(Y)` and `target.arch(Z)` recognized as compile-time-builtin call shapes (analogous to the existing `cfg(...)` macro family but always compile-time-resolved).
- **Const-fold:** compiler resolves the call at the `if` site against the build's target manifest (CLI flags `--target-cpu`, `--target-feature`, OS+arch detected from build host or `--target-triple`).
- **DCE:** the resolved `false` branch is elided pre-codegen — no stub, no dead helper symbol.

Build manifest (CLI / config):
- `nuc build --target-feature=avx512,fp4,tensor_cores`
- Default: detect host CPU features for native builds; conservative subset for cross-compile.

## Cost

~300 LOC compiler-side (target-builtin parser + const-fold + DCE wiring). Reuses existing `cfg(...)` machinery.

## Hot-path risk

None. The check is compile-time; runtime sees only the surviving branch.

## Frontier connection

Direct frontier writeup §3.2.1 "Compile-time hardware queries." Pairs with **RFC-0049 memory-space type tags** (target queries decide which memory-space tag is valid).

## Closure criteria

- `if target.has(AVX512) { ... } else { ... }` resolves at compile time per target manifest.
- Dead branch is DCE'd — symbol table doesn't list the elided helper.
- `nuc build --target-feature=fp4` flips `target.has(FP4)` from false → true.
- Round-2 self-host fixed-point holds (target manifest stable across rounds).
