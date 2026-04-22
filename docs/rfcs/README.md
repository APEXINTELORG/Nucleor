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

### Tier 1 — RT, robotics, allocator foundations

| # | Title | Status | Target |
|---|---|---|---|
| [0001](RFC-0001-rt-attributes.md) | RT Function Attributes — `#[no_alloc, no_panic, no_dyn, deadline]` | Draft | v0.3.0 |
| [0002](RFC-0002-allocator-types.md) | Allocator Types — `Box<T, A: Allocator>`, Arena / Pool / TLSF | Draft | v0.3.0 |
| [0003](RFC-0003-typed-frames.md) | Typed Coordinate Frames — `Pose<F: Frame>` | Draft | v0.4.0 |
| [0004](RFC-0004-assume.md) | `#[assume(...)]` — explicit non-panic / bounds proofs | Draft | v0.4.0 |
| [0005](RFC-0005-units.md) | `unit<T, dim>` — typed dimensional units | Draft | v0.6.0 |
| [0006](RFC-0006-design-by-contract.md) | DbC — `#[require], #[ensure], #[invariant]` | Draft | v0.5.0 |
| [0007](RFC-0007-atomic.md) | `#[atomic]` + lock-free queues (SPSC, MPMC) | Draft | v0.5.0 |
| [0008](RFC-0008-isr.md) | `#[isr]` — interrupt service routine attribute | Draft | v0.6.0 |
| [0009](RFC-0009-heptane-wcet.md) | Static WCET via Heptane | Draft | v0.7.0 |
| [0010](RFC-0010-dlpack.md) | DLPack — zero-copy tensor interchange | Draft | v0.7.0 |
| [0011](RFC-0011-nuc-cxx.md) | `nuc-cxx` — paired `.h` + `.nr` C++ FFI codegen | Draft | v0.4.0 |
| [0012](RFC-0012-nuc-bindgen.md) | `nuc-bindgen` — libclang C/C++ binding generator | Draft | v0.4.0 |
| [0013](RFC-0013-urdf-static-frames.md) | URDF-aware compile-time frame chain verification | Draft | v0.5.0 |
| [0014](RFC-0014-max-depth.md) | `#[max_depth = N]` — bounded recursion attribute | Draft | v0.5.0 |

### Tier 2 — language essentials (v0.2 foundation)

| # | Title | Status | Target |
|---|---|---|---|
| [0015](RFC-0015-numeric-types.md) | Numeric types — i8…i128, u8…u128, f16/bf16/f32/f64/f8 | Draft | v0.2.0 |
| [0016](RFC-0016-result-option-match.md) | Result/Option/match/`?` | Draft | v0.2.0 |
| [0017](RFC-0017-collections.md) | String, HashMap, BTreeMap, HashSet, VecDeque | Draft | v0.2.0 |
| [0018](RFC-0018-modules.md) | Module system — `mod`, `pub`, `use`, paths | Draft | v0.2.0 |
| [0019](RFC-0019-package-manager.md) | Package manager — `nuc.toml`, registry, resolver | Draft | v0.2.0 (resolver) → v0.5.0 (registry) |
| [0020](RFC-0020-diagnostics.md) | Diagnostic upgrade — spans, snippets, color, fixes | Draft | v0.2.0 |
| [0021](RFC-0021-test-framework.md) | Test framework — `#[test]`, `nuc test`, assertions | Draft | v0.2.0 |
| [0022](RFC-0022-cross-platform.md) | Cross-platform — Linux, macOS, cross-compile | Draft | v0.2.0 → v0.5.0 |

### Tier 2 — language extensions (v0.4)

| # | Title | Status | Target |
|---|---|---|---|
| [0023](RFC-0023-pattern-matching.md) | Rich patterns — ranges, guards, slice, or-, @-bindings | Draft | v0.4.0 |
| [0024](RFC-0024-iterators.md) | Iterator trait + adapter chain | Draft | v0.4.0 |
| [0025](RFC-0025-closures.md) | Closures with capture (`Fn`, `FnMut`, `FnOnce`) | Draft | v0.4.0 |
| [0026](RFC-0026-trait-objects.md) | Trait objects — `dyn Trait`, vtables | Draft | v0.4.0 |
| [0027](RFC-0027-lifetimes.md) | Explicit lifetime parameters | Draft | v0.4.0 |
| [0028](RFC-0028-format-strings.md) | Format strings — `format!`, `println!`, `Display`/`Debug` | Draft | v0.4.0 |
| [0029](RFC-0029-doc-generator.md) | Documentation generator — `nuc doc`, `///` comments, doc tests | Draft | v0.4.0 |
| [0030](RFC-0030-async-decision.md) | Async / await — decision and phased plan | Draft | v0.4 (decision) → v0.8 (sugar) |

### Tier 3 — Nucleor-unique differentiators

| # | Title | Status | Target |
|---|---|---|---|
| [0031](RFC-0031-algebraic-laws.md) | Algebraic laws as a verified rewrite system | Draft | v0.5.0 |
| [0032](RFC-0032-effects.md) | Effects — `pure fn`, `requires`, `restricts` | Draft | v0.6.0 |

**32 RFCs drafted, all Draft status.** Together with the three
process docs (`docs/process/`), they specify the full v0.2 → v0.8
design surface for safety / robotics / AI.

## Process docs

| Doc | Purpose |
|---|---|
| [SemVer & Release Process](../process/semver-and-release.md) | Versioning policy, release schedule, breaking-change discipline |
| [Contributing](../process/contributing.md) | How to build, test, file issues, submit PRs, RFC process |
| [Nucleor-Safe Subset](../process/nucleor-safe-subset.md) | Safety-cert subset spec (final in v0.6) |

## RFCs by release

### v0.2.0 — foundation
- 0015 numerics, 0016 Result/Option/match, 0017 collections, 0018 modules,
  0019 packages (manifest+resolver), 0020 diagnostics, 0021 test framework,
  0022 cross-platform (Linux+macOS)

### v0.3.0 — Robotics Foundation
- 0001 RT attributes, 0002 allocator types

### v0.4.0 — Robotics Stack
- 0003 typed frames, 0004 assume, 0011 nuc-cxx, 0012 nuc-bindgen,
  0023 patterns, 0024 iterators, 0025 closures, 0026 trait objects,
  0027 lifetimes, 0028 format strings, 0029 doc generator,
  0030 async decision

### v0.5.0 — Production Robotics
- 0006 contracts, 0007 atomic, 0013 URDF, 0014 max_depth,
  0019 packages (registry MVP), 0022 cross-platform (full),
  0031 algebraic laws

### v0.6.0 — Embedded + AI Inference
- 0005 units, 0008 ISR, 0032 effects

### v0.7.0 — AI Training + RT Linux
- 0009 Heptane WCET, 0010 DLPack

### v0.8.0 — Industrial RTOS + Async
- 0030 async (sugar)

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
