# RFC-0049 — Memory-Space Type Tags on Tensors

**Status:** Draft (frontier easy-win — V2.4)
**Date:** 2026-05-03

## Motivation

Heterogeneous-hardware programs need to know WHICH memory pool a tensor lives in: HBM (high-bandwidth memory on the GPU/accelerator), DDR (host RAM), CXL (memory-pool fabric), Scratchpad (small fast on-die SRAM). Today Nucleor tensors are dimension-only — a `Tensor<f32>` could live anywhere, and operations that require co-location of operands (matmul fanning across HBM banks vs DDR↔HBM DMA-then-matmul) have no compile-time check.

The frontier writeup proposes hardware-location as a TYPE: `Tensor<f32, HBM>`. Wrong-pool ops fail at type-check.

## Design

```nucleor
struct MemSpace_HBM;
struct MemSpace_DDR;
struct MemSpace_CXL;
struct MemSpace_Scratchpad;
struct MemSpace_NPU_SRAM;
struct MemSpace_Default;        // = HBM on GPU, DDR on CPU

struct Tensor<T, Space = MemSpace_Default> {
    data: i64,
    shape: [i64; 4],
}

fn matmul<S>(a: Tensor<f32, S>, b: Tensor<f32, S>) -> Tensor<f32, S> { ... }
// matmul requires both operands in the same memory space.

fn migrate<From, To>(t: Tensor<f32, From>) -> Tensor<f32, To> { ... }
// explicit cross-pool DMA.
```

Allocation primitives (rod-level, but with type-system enforcement):
- `alloc::<HBM>(shape)` returns `Tensor<f32, MemSpace_HBM>`
- `alloc::<CXL>(shape)` returns `Tensor<f32, MemSpace_CXL>`
- `prefetch::<HBM>(t: &Tensor<f32, DDR>)` async-warms HBM
- `migrate(t)` blocks until DMA completes

## Implementation

- Type-check: `Tensor<T, S>` types compare both T and S parameters. Phantom-typed S (zero runtime cost — the runtime tensor handle has the same i64 layout regardless of pool).
- Codegen: the alloc primitive dispatches to the matching runtime helper (`__nucleor_alloc_hbm`, `__nucleor_alloc_ddr`, etc.). Today only `__nucleor_alloc_ddr` (host RAM via `malloc`) ships; the GPU/CXL/Scratchpad helpers are **STUBS** that fall back to host RAM with a runtime warning.
- Stdlib: `std.mem` adds `alloc<S>`, `prefetch<S>`, `migrate`, `pin`, `evict` primitives. CPU-only path returns the tensor unchanged; GPU-pool path requires future GPU runtime ship.

## Cost

~200 LOC compiler-side (parameterized type with default param). ~150 LOC stdlib (memory-space marker structs + alloc dispatch). GPU/CXL runtime is FUTURE — out of scope for this RFC; type-system substrate only.

## Hot-path risk

Zero. Phantom-typed.

## Frontier connection

Direct frontier writeup §3.2.1 "Hardware-location types." Pairs with **RFC-0048 hardware capability queries** (the alloc-pool decisions condition on `target.has(HBM)`).

## Closure criteria

- `Tensor<f32, MemSpace_HBM>` and `Tensor<f32, MemSpace_DDR>` are distinct types.
- `matmul(a_hbm, b_ddr)` rejects with TYP-008 mem-space mismatch.
- `migrate(t)` accepts cross-pool conversion explicitly.
- CPU-only fallback works for all pool types.
- Round-2 self-host fixed-point holds.
