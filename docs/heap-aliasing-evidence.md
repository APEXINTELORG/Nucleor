# Heap Aliasing — Phase 1 Evidence Note (RFC-0062 G-3)

**Status:** Phase 1 docs (v0.8.18, 2026-05-04)

Per RFC-0062 §3.3 G-3 Phase 1: explicitly document the limitation
of the v0.x borrow-tracker for heap-resident references.

## The limitation

The pre-v1.0 borrow tracker reasons about borrows expressed
syntactically in source — `&v`, `&mut v`, function parameters,
etc. The tracker does NOT detect aliasing that arises through:

1. **Vec-of-references containing the same target:** pushing two
   `&T` borrows of the same `T` into a `Vec<&T>` and then walking
   the Vec produces aliased reads. The Vec hides the aliasing
   from the syntactic tracker.

2. **HashMap value re-binding:** taking a borrow on a HashMap
   value, then mutating the HashMap through a separate handle,
   then re-using the original borrow. The original borrow may
   point into freed or relocated memory if the map resized.

3. **Cross-rod data shared via process-global registries:** the
   governance registry, the energy-budget registry, and similar
   process-globals are intentionally shared mutable state. They
   carry their own per-registry locking discipline; the borrow
   tracker doesn't see them as aliased.

## Adopter mitigation today

Until Phase 2 of G-3 (v1.x), adopter code that lives in this
territory should:

- **Prefer indexing over reference-storing:** store `Vec<i64>`
  indexes into a single owned vector rather than `Vec<&i64>`
  borrows of separate vectors.
- **Avoid HashMap re-mutation while a value borrow is live:**
  finish reading from the borrowed value, then drop the borrow
  before any insert/remove/clear on the map.
- **Treat the registries as the single source of truth they
  are:** don't shadow registry state with local mutable copies.

## Evidence for the claim

The borrow tracker source lives in
`compiler/nucleor_s1_compiler.nr` under the `borrow_*` and
`ownership_*` helper families. Reading those functions confirms
the syntactic-only reasoning:

- The tracker walks AST scopes, not heap-region symbolics.
- Vec pushes are tracked as `vec_push(v, x)` move semantics on
  `x` but not as a fanout of borrows derived from `x`.
- HashMap inserts are tracked as ownership transfers of the
  inserted value but not as invalidation of outstanding borrows
  of OTHER values in the map.

This is the correct v0.x design (precision is bounded by what
the syntactic checker can prove without dataflow), but it IS a
gap relative to the marketing surface "Rust-equivalent borrow
checking." The gap is closed in Phase 2 by adding region
inference for Vec-of-reference and HashMap-value cases per
RFC-0062 §3.3 G-3 P2.

## Phase 2 plan (out of scope this ship)

Phase 2 of G-3 adds two orthogonal pieces:

1. **Vec-of-reference flow analysis** — when a `Vec<&T>` (or
   `&mut T`) is constructed, the tracker conservatively assumes
   every element borrows from the same region until proven
   otherwise. This is sound but coarse; adopters who rely on
   distinct-region semantics will hit a new diagnostic with the
   workaround documented inline.

2. **HashMap rehash invalidation** — borrows of HashMap values
   are invalidated at every `insert/remove/clear/reserve` call
   on the map. The tracker enforces this via a region-token
   bumped on each mutating call.

Phase 4 (v1.0) promotes any false-negative cases that survive
Phase 2 to a hard error; until then, the diagnostic surfaced is
a warning with an explain link to this doc.
