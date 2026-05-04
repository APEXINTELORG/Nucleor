# RFC-0059 — Multi-Level IR (5-Stage MLIR-Style) — SKETCH ONLY

**Status:** Sketch (frontier — V3.x deferred — pending user commit)
**Date:** 2026-05-03
**Note:** This is a one-page architectural teaser, not a full RFC. The full design requires user buy-in to a multi-quarter v3.0 cycle. Do not implement until that decision is made.

## The thesis

Today Nucleor has ONE IR — a single-level pool-of-nodes structure that mixes high-level constructs (struct ctor, match, async) with low-level ones (load, store, binop, br_cond). It works, it's fast, and it's what made the self-host fixed-point shippable.

The frontier writeup (and MLIR's example) argues that scaling to multiple execution forms (CPU + GPU + photonic + neuromorphic + quantum) and multiple optimization passes per form requires a tower:

1. **Intent IR** — what the program means semantically (close to the source surface)
2. **Algorithm IR** — what computation to perform (e.g. "matmul of these shapes")
3. **Schedule IR** — how to perform it (tile sizes, fusion, reorder, cache blocking)
4. **Device IR** — where on the hardware (which GPU, which SM, which scratchpad)
5. **Machine IR** — what instructions (LLVM IR, PTX, SPIR-V, OpenQASM, MZI mesh config)

Each level is a "dialect" — a closed set of ops + verification rules. Lowering passes translate from level N to level N-1. Optimization passes operate within a level.

## Why this matters

- Photonic / neuromorphic / quantum execution forms need their own dialects — single monolithic IR can't represent "an MZI mesh phase shift" and "an i64 add" with the same node kind cleanly.
- Schedule-level optimization (fusion, tiling, reorder) is much easier when separate from algorithm-level.
- Vendor extensibility: third parties can add a `@dialect(my_npu)` extension without forking the compiler.
- MLIR-compatibility: Nucleor could LOWER into MLIR for ecosystem reach (LLVM, IREE, XLA, etc.) without rewriting the front end.

## Why we DON'T do this now

- It's the biggest single architectural commitment in the entire project.
- The existing IR works for everything we ship today.
- Multi-level IR adds compile-time cost (more passes) — must be balanced against the existing self-host perf budget.
- Many frontier features (RFC-0046 through RFC-0058) DON'T require multi-level IR — they just add types + dialects on top.

## Path forward

1. Ship the V2.x frontier RFCs (RFC-0046 through RFC-0058) on the existing single-level IR.
2. Observe which RFCs hit IR-modeling friction.
3. Make the multi-level commitment when (a) ≥3 RFCs are blocked on it OR (b) MLIR-ecosystem interop becomes a strategic priority.
4. Allocate a 6-month v3.0 cycle. First, refactor existing IR into a "Machine" dialect. Then add Algorithm + Schedule dialects. Then experiment with Intent + Device.

## Status

Pending user commit. Do not start implementation.

## Closure criteria (when implemented — far future)

- Existing single-level IR passes Round-2 fixed-point unchanged after refactor.
- At least one frontier execution form (photonic OR neuromorphic) lowers cleanly through the 5 levels.
- A third-party `@dialect(...)` extension can be loaded without recompiling the compiler.
