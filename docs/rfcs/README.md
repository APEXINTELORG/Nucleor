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

### Cross-cutting contracts

| Doc | Topic | Status |
|---|---|---|
| [HELPER-CONTRACT](HELPER-CONTRACT.md) | Helper schema inventory & population — protocol document | Phase 1 + Phase 2 done in v0.2.40; Phase 2 population at 92.9% via v0.2.73–76 |
| [helper_manifest.toml](helper_manifest.toml) | 676-helper schema map (TOML, generated) | Mech v0.2.40, populated v0.2.73–76 (628/676 rows fully annotated; remaining 48 are intentional v0.4 placeholders) |
| [helper_manifest_schema.md](helper_manifest_schema.md) | Per-field reference for `helper_manifest.toml` | v0.2.40, schema vocabulary expanded v0.2.73 (`"sync"` effect tag) + v0.2.75 (per-class population state table) |
| [rod_manifest.toml](rod_manifest.toml) | 121-rod catalog (TOML, generated) | Companion to helper manifest, v0.2.46 |
| [rod_manifest_schema.md](rod_manifest_schema.md) | Per-field reference for `rod_manifest.toml` | v0.2.46 |

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
| [0015](RFC-0015-numeric-types.md) | Numeric types — i8…i128, u8…u128, f16/bf16/f32/f64/f8 | **Implemented (partial)** v0.1.46–v0.1.64 | v0.2.0 (lattice + cast warnings) → v0.4 (strict-mode) |
| [0016](RFC-0016-result-option-match.md) | Result/Option/match/`?` | **Implemented (partial)** v0.1.50–v0.1.61 | v0.2.0 (`?` operator + MATCH-001/002) → v0.4 (generic enums) |
| [0017](RFC-0017-collections.md) | String, HashMap, BTreeMap, HashSet, VecDeque | **Implemented** v0.1.27–v0.1.47 | v0.2.0 |
| [0018](RFC-0018-modules.md) | Module system — `mod`, `pub`, `use`, paths | **Implemented (partial)** v0.1.52–v0.1.65 | v0.2.0 (`use std::` + `mod foo;` + `nuc fix --imports`) → v0.4 (resolver, `pub use`) |
| [0019](RFC-0019-package-manager.md) | Package manager — `nuc.toml`, registry, resolver | **Implemented (partial)** v0.1.33–v0.1.55 | v0.2.0 (manifest, lockfile, install, workspace) → v0.5.0 (registry, PubGrub, git) |
| [0020](RFC-0020-diagnostics.md) | Diagnostic upgrade — spans, snippets, color, fixes | **Implemented (partial)** v0.1.34–v0.1.59 | v0.2.0 (LineMap + JSON + 38 explain entries) → v0.4 (full span migration) |
| [0021](RFC-0021-test-framework.md) | Test framework — `#[test]`, `nuc test`, assertions | **Implemented** v0.1.10–v0.1.55 | v0.2.0 |
| [0022](RFC-0022-cross-platform.md) | Cross-platform — Linux, macOS, cross-compile | **Implemented (partial)** v0.1.30 (POSIX `nuc` wrapper, `_WIN32` audit) | v0.2.0 → v0.3.0 (Linux/macOS bin) → v0.5.0 (sysroots) |

### Tier 2 — language extensions (v0.4)

| # | Title | Status | Target |
|---|---|---|---|
| [0023](RFC-0023-pattern-matching.md) | Rich patterns — ranges, guards, slice, or-, @-bindings | Draft | v0.4.0 |
| [0024](RFC-0024-iterators.md) | Iterator trait + adapter chain | **Implemented (partial)** v0.2.9 | v0.2 (Vec<i64> map/filter/fold/each/sum/min/max via fn-ptrs) → v0.4 (trait + adapter chain with closures) |
| [0025](RFC-0025-closures.md) | Closures with capture (`Fn`, `FnMut`, `FnOnce`) | Draft | v0.4.0 |
| [0026](RFC-0026-trait-objects.md) | Trait objects — `dyn Trait`, vtables | Draft | v0.4.0 |
| [0027](RFC-0027-lifetimes.md) | Explicit lifetime parameters | Draft | v0.4.0 |
| [0028](RFC-0028-format-strings.md) | Format strings — `format!`, `println!`, `Display`/`Debug` | **Implemented (partial)** v0.2.6 | v0.2 (`format_i64/str/hex/2_ii/2_si` builtins, one `{}` per call) → v0.4 (variadic + `Display`/`Debug` traits) |
| [0029](RFC-0029-doc-generator.md) | Documentation generator — `nuc doc`, `///` comments, doc tests | **Implemented (skeleton)** v0.1.65 | v0.2.0 (skeleton) → v0.4 (param rendering, navigation, doc tests) |
| [0030](RFC-0030-async-decision.md) | Async / await — decision and phased plan | Draft | v0.4 (decision) → v0.8 (sugar) |

### Tier 3 — Nucleor-unique differentiators

| # | Title | Status | Target |
|---|---|---|---|
| [0031](RFC-0031-algebraic-laws.md) | Algebraic laws as a verified rewrite system | Draft | v0.5.0 |
| [0032](RFC-0032-effects.md) | Effects — `pure fn`, `requires`, `restricts` | Draft | v0.6.0 |

**32 RFCs drafted; 8 Tier-2 (RFC-0015..0022) + RFC-0029 carry
Implemented or Implemented-partial status as of v0.1.65.**
Together with the three process docs (`docs/process/`), they
specify the full v0.2 → v0.8 design surface for safety / robotics
/ AI.

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
