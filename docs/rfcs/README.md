# Nucleor RFCs

Design documents for major language and runtime changes. Each RFC
specifies a single feature in enough depth that implementation can
proceed without re-design.

## Status legend

- **Draft** — written, not yet approved by maintainer.
- **Accepted** — design locked; implementation pending.
- **Implemented** — landed in the named release.
- **Superseded by RFC-NNNN** — replaced.
- **Withdrawn** — abandoned.

## Index

| # | Title | Status | Target |
|---|---|---|---|
| [0001](RFC-0001-rt-attributes.md) | Real-Time Function Attributes — `#[no_alloc]`, `#[no_panic]`, `#[no_dyn]`, `#[deadline]` | Draft | v0.3.0 |
| [0002](RFC-0002-allocator-types.md) | Allocator Types — `Box<T, A: Allocator>`, Arena / Pool / TLSF | Draft | v0.3.0 |
| [0003](RFC-0003-typed-frames.md) | Typed Coordinate Frames — `Pose<F: Frame>`, compile-time TF correctness | Draft | v0.4.0 |
| [0004](RFC-0004-assume.md) | `#[assume(...)]` — explicit non-panic / bounds proofs | Draft | v0.4.0 |
| [0005](RFC-0005-units.md) | `unit<T, dim>` — typed dimensional units | Draft | v0.6.0 |
| [0006](RFC-0006-design-by-contract.md) | Design by Contract — `#[require]`, `#[ensure]`, `#[invariant]` | Draft | v0.5.0 |
| [0007](RFC-0007-atomic.md) | `#[atomic]` and lock-free data structures | Draft | v0.5.0 |
| [0008](RFC-0008-isr.md) | `#[isr]` — interrupt service routine attribute | Draft | v0.6.0 |
| [0009](RFC-0009-heptane-wcet.md) | Static WCET via Heptane integration | Draft | v0.7.0 |
| [0010](RFC-0010-dlpack.md) | DLPack — zero-copy tensor interchange | Draft | v0.7.0 |
| [0011](RFC-0011-nuc-cxx.md) | `nuc-cxx` — paired `.h` + `.nr` C++ FFI codegen | Draft | v0.4.0 |
| [0012](RFC-0012-nuc-bindgen.md) | `nuc-bindgen` — libclang-driven C/C++ binding generator | Draft | v0.4.0 |
| [0013](RFC-0013-urdf-static-frames.md) | URDF-aware compile-time frame chain verification | Draft | v0.5.0 |
| [0014](RFC-0014-max-depth.md) | `#[max_depth = N]` — bounded recursion attribute | Draft | v0.5.0 |

**14 RFCs drafted, all Draft status.** Together they specify the
full v0.3 → v0.7 design surface for the safety / robotics / AI
roadmap.

## RFCs by release

### v0.3.0 — Robotics Foundation
- 0001 RT attributes (`#[no_alloc, no_panic, no_dyn, deadline]`)
- 0002 Allocator types (Arena / Pool / TLSF)

### v0.4.0 — Robotics Stack
- 0003 Typed coordinate frames
- 0004 `#[assume(...)]` — escape hatch for `#[no_panic]`
- 0011 `nuc-cxx` — C++ FFI bridge
- 0012 `nuc-bindgen` — C/C++ header binding generator

### v0.5.0 — Production Robotics
- 0006 Design by contract (`#[require, ensure, invariant]`)
- 0007 `#[atomic]` + lock-free data structures
- 0013 URDF-aware compile-time frame chains
- 0014 `#[max_depth]` — bounded recursion

### v0.6.0 — Embedded + AI Inference
- 0005 `unit<T, dim>` — typed dimensional units
- 0008 `#[isr]` — interrupt service routines

### v0.7.0 — AI Training + Real-Time Linux
- 0009 Heptane WCET integration (provable static WCET)
- 0010 DLPack — zero-copy tensor exchange (PyTorch / JAX / MLX)

## Authoring an RFC

Every RFC follows the template:

1. **Header** — Number, title, status, author, dates, target
   release, dependencies.
2. **Summary** — 5–10 lines plus a code example. The TL;DR.
3. **Motivation** — what's wrong today, what other languages do
   (table), what we want.
4. **Design** — full specification with examples and diagnostics.
5. **Implementation** — LOC estimates per component (compiler,
   runtime, stdlib), test plan, migration story.
6. **Alternatives considered** — at least three rejected designs
   with reasons.
7. **Open questions** — implementation-review items with author
   recommendation.
8. **Definition of done** — checklist of acceptance criteria.
9. **Future extensions** — out-of-scope follow-ons.
10. **Acceptance checklist** — sign-off gate before implementation.

Open a PR with the RFC at `docs/rfcs/RFC-NNNN-slug.md`. Add an entry
to the index above.
