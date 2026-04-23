# Nucleor-Safe Subset

**Version:** Draft v0.1 (will be finalized in v0.6)
**Audience:** users targeting safety-critical certification
                (ISO 26262 ASIL-D, IEC 61508 SIL-3, DO-178C Level A)
**Last updated:** 2026-04-22

## Purpose

This document defines a **subset of Nucleor** that is suitable for
formal safety certification. Code that conforms to the subset can be
audited and certified; code that doesn't, cannot.

This is the Nucleor analog of MISRA-C, AUTOSAR-C++, SPARK Ada.

The subset will be **finalized in v0.6** alongside `nuc check --safe`
mode. This draft establishes the design ceiling so v0.2-v0.5 work
doesn't paint into a corner.

## Mandatory rules

A function is **Nucleor-Safe** iff:

### S-001 Real-time attributes required for control loops

Every function in the call graph below the top-level control loop
entry MUST carry one of:
- `#[no_alloc, no_panic, no_dyn, deadline = T]` (RFC-0001)
- `#[isr]` (RFC-0008)
- `#[atomic]` (RFC-0007)

### S-002 No unrestricted allocator

`Allocator::Global` (RFC-0002) is forbidden in safe-subset code.
Use Arena, Pool, TLSF only.

### S-003 No dynamic dispatch

`Box<dyn Trait>`, `&dyn Trait` forbidden. All dispatch is static
(monomorphized).

### S-004 No panicking expressions

Every potentially-panicking expression must be guarded by
`#[no_panic]`-passing code paths. `unwrap()` is forbidden — use
`unwrap_or` / `?` / `match`.

### S-005 No unbounded recursion

All recursion bounded by `#[max_depth = N]` (RFC-0014). Compiler
verifies depth at compile time.

### S-006 No unbounded loops

Every loop must have a static or `assume!`-known bound. `nuc check
--wcet` (RFC-0009) verifies. `loop {}` without `break` forbidden.

### S-007 No FFI without audit

Every `extern fn` must reference an audit manifest entry (RFC-0001
§3.5) declaring its alloc/panic/effect properties. Compiler enforces.

### S-008 No `unsafe` without justification

Every `unsafe` block must carry a comment block:
```
// SAFETY: <why this is safe; what invariants are upheld>
```
Compiler emits a warning if missing.

### S-009 No raw pointers in user code

`*const T` / `*mut T` permitted in FFI shims only. User code uses
references.

### S-010 No `assume_unchecked!`

`assume!` (debug-checked) only. `assume_unchecked!` forbidden.

### S-011 No async

`async fn` forbidden. Concurrency via threads + channels +
`#[atomic]` only.

### S-012 No GC

(Trivially — Nucleor has no GC.)

### S-013 Float arithmetic with explicit rounding

All float ops must declare rounding mode. Default to round-to-nearest;
explicit `round_toward_zero`, `round_up`, `round_down` available.

### S-014 No floating-point in `#[deadline]` paths without WCET cost

Float ops have variable cost on some hardware. WCET cost table must
account.

### S-015 All laws proven, not just property-tested

`@law` annotations must SMT-prove (RFC-0031) under
`--profile=cert`. Property-test-only laws forbidden in safe code.

### S-016 Bounded stack

Total stack budget configured per project. Compiler verifies all
function call chains fit.

### S-017 No deprecated features

Any feature marked `#[deprecated]` is forbidden. Refactor first.

## Recommended (not enforced)

- `#[ensure]` / `#[require]` (RFC-0006) on all public APIs
- Typed coordinate frames (RFC-0003) for all spatial code
- Typed units (RFC-0005) for all dimensional quantities
- All laws (`@law`) declared on associative/commutative/identity ops

## Allowed feature subset

The Nucleor-Safe subset PERMITS:
- All RFC-0001 attributes
- RFC-0002 allocator types (Arena, Pool, TLSF only)
- RFC-0003 typed frames
- RFC-0004 `assume!` (debug-checked form only)
- RFC-0005 units
- RFC-0006 contracts
- RFC-0007 atomic + lock-free queues
- RFC-0008 ISRs
- RFC-0009 Heptane WCET
- RFC-0014 `#[max_depth]`
- RFC-0015 numeric types
- RFC-0016 Result/Option/match (without `unwrap`)
- RFC-0017 collections (with pre-sized + try_*)
- RFC-0023 pattern matching
- RFC-0024 iterators (no Box<dyn>)
- RFC-0026 trait objects ONLY through `&dyn` (not `Box<dyn>`)
- RFC-0027 lifetimes
- RFC-0031 laws (with SMT proof)
- RFC-0032 effects (`pure fn` strongly recommended)

The subset FORBIDS (in safe-tagged code):
- RFC-0019 package manager run-time fetches (lockfile-only)
- RFC-0030 async/await
- Trait objects via `Box<dyn>`
- `assume_unchecked!`
- `unsafe` without justification
- Globals that aren't `const`

## Mode of enforcement

```
nuc check --safe <project>
```

Reports per-function compliance. Build fails on any violation.
Output includes:
- Per-rule compliance count
- Per-violation source location + suggestion
- Optional JSON for CI integration

## Certification artifact

`nuc cert --output=cert-bundle.zip` (planned v0.7) produces an
auditor-ready bundle:
- The Nucleor-Safe report
- All RFC docs the code depends on
- All algebraic-law proofs
- All Heptane WCET reports
- Signed-source-tree manifest (sha256 + GPG sig)
- License attribution

This bundle is what an auditor reviews.

## Roadmap

| Release | Subset milestone |
|---|---|
| v0.2.0 | Tier-2 RFCs shipped (numerics, Result/Option/match, collections, modules, packages, diagnostics, tests, cross-platform). RFC-0001..0004 are still Draft (target v0.3.0–v0.4.0); the safety subset spec is **frozen** but full enforcement waits on those Tier-1 RFCs landing. |
| v0.3.0 | Full RT attributes (RFC-0001) + allocator types (RFC-0002); subset 60% enforceable |
| v0.4.0 | Lifetimes + frames + assume; subset 80% enforceable |
| v0.5.0 | Contracts + atomic + URDF; subset 90% enforceable |
| v0.6.0 | Units + ISR + final subset spec; `nuc check --safe` ships |
| v0.7.0 | Heptane integration; `nuc cert` ships; full enforcement |
| v0.8.0 | First customer-funded certification engagement (target) |

## Known gaps

- We will NOT pursue formal certification paperwork without a paying
  customer. The subset is "capable of being certified," not
  "is certified."
- ISO 13849 (machinery directive) overlap with ISO 26262 still being
  reviewed.
- Multi-core analysis (shared cache contention modeling) is out of
  scope until v0.8+.

## Contact

Email subset@nucleor.dev for questions. Bug reports for the subset
spec via GitHub Issues with the `subset` label.
