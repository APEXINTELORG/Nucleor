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

## Planned (not yet drafted)

| # | Title | Target |
|---|---|---|
| 0004 | `#[assume(...)]` — explicit non-panic / bounds proofs | v0.4.0 |
| 0005 | `unit<T, dim>` — typed dimensional units (resurrect from V1 quarantine) | v0.6.0 |
| 0006 | `#[max_depth = N]` — bounded recursion attribute | v0.4.0 |
| 0007 | `#[atomic]` — lock-free data structure attribute | v0.5.0 |
| 0008 | `#[isr]` — interrupt-service-routine attribute | v0.6.0 |
| 0009 | Static WCET via Heptane integration | v0.7.0 |
| 0010 | DLPack — zero-copy tensor handoff with PyTorch / JAX / MLX | v0.7.0 |
| 0011 | `nuc-cxx` — paired `.h` + `.nr` C++ FFI codegen | v0.4.0 |
| 0012 | `nuc-bindgen` — libclang-driven C/C++ binding generator | v0.4.0 |
| 0013 | URDF-aware compile-time frame chain verification | v0.5.0 |

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
