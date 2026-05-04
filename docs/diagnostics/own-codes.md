# OWN-* Diagnostic Codes — Reservation Index

This file is the canonical reservation index for the `OWN-NNN`
diagnostic-code namespace used by the ownership / borrow / move
checker. Each entry has:

- **Code:** `OWN-NNN`
- **Severity:** error | warning
- **Status:** active | reserved | retired
- **Phase:** P1 docs / P2 surface / P3 enforcement / P4 default-on
- **Triggers when:** the condition the diagnostic flags
- **Phase 4 promotion:** the v1.0-gate decision

Codes are reserved (with explain text) before they're enforced.
This means an adopter who hits the eventual error sees the same
code that appeared in pre-1.0 docs — the explain page is stable
even when the enforcement phase isn't.

## Reserved (RFC-0062)

### OWN-012 — Double-free / use-after-drop diagnostic

- **Severity:** error (Phase 4); warning (Phase 2/3)
- **Status:** reserved (Phase 1, no detection yet)
- **Phase:** P1 (this ship — code reserved + explain text)
- **Triggers when:** the same owned heap value (Vec, String,
  HashMap, struct field of those, etc.) is moved-then-dropped
  twice, OR is used after the move boundary that transferred
  ownership. Phase 2 surfaces a warning per RFC-0062 §3.3 G-4.
- **Phase 4 promotion:** v1.0 hard error.
- **Adjacent codes:** OWN-VAL-1 (use-after-move at function
  boundary), OWN-VAL-3 (drop without clear order), MS-1
  (use-after-free at runtime).

**Explain text:**

```
error[OWN-012]: double-free / use-after-drop

  Variable `X` was moved at line A and either dropped twice or
  used past its move boundary. Owned heap values can only be
  freed once; reading or freeing them after the original move
  point is undefined behavior in C-runtime terms and a
  memory-safety violation per the language guarantees.

  --> path/to/file.nr:LINE
   |
   | LINE | <SOURCE>
   |      |  ^^^^^^^

  Note: In Phase 1 / 2 / 3 builds this diagnostic is reserved
  but not always emitted at compile time — runtime double-frees
  may surface as runtime aborts via the C-runtime allocator
  guard. Phase 4 (v1.0) promotes the diagnostic to a static
  error.

  Help: extract the moved value into a let binding before the
  second use, or pass by reference (`&X`) instead of by value.

  Reference: RFC-0062 §3.3 G-4.
```

## Active

### OWN-VAL-1 — Use-after-move at function boundary
- Status: active (since v0.6.x)
- Reference: language-reference.md §move-semantics.

### OWN-VAL-3 — Drop ordering ambiguous
- Status: active.

(Other OWN-VAL-N codes documented in language-reference.md;
this index will absorb them in subsequent ships.)

## Allocation rule

New OWN-* codes are allocated in increments of one starting
from OWN-001. Reserved codes count against the namespace —
OWN-012 is reserved here, OWN-013 is the next allocation.

Reservation can move to active (when surface lands) or to
retired (when superseded). Retired codes remain in this index
with a `Status: retired (replaced by OWN-NNN)` line.
