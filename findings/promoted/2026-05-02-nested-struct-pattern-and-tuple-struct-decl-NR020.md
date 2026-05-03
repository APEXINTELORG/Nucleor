---
title: Two canonical Rust pattern/struct shapes both NR020-panic at parse — (1) nested struct destructuring `match l { Line { a: Point { x, y: _ }, b: _ } => x }` (and the let-binding equivalent) and (2) tuple-struct declarations `struct P(i64, i64);`
severity: parse-rejection (canonical-rust-shape)
probe_file: probes/match/nested_struct_pattern_and_tuple_struct.nr (probe-branch)
diagnostic_actual: NR020 generic parse error on both shapes
diagnostic_expected: accept (and recurse into nested patterns) or emit clean v0.6-boundary diag naming the unsupported shape
discovered_against: main v0.6.13 (probe rebased)
commit: probe (post-rebase) + main 98c13f4
status: DOC-ONLY — nested struct patterns and tuple-struct declarations are parse extensions for v1. Today adopters use single-level destructure + manual field access for nested shapes, and named-field structs for the tuple-struct shape.
---

## Closure (analysis-only — no compiler change)

### Sub-case 1 — nested struct pattern in match arm

`Line { a: Point { x, y: _ }, b: _ }` requires the match-arm
pattern parser to recurse into the inner `Point { x, y: _ }`
struct pattern. Today `parse_match_struct_binding_block` reads
field-bindings as identifiers only — no recursion into inner
struct shapes.

### Sub-case 2 — tuple-struct declaration

`struct P(i64, i64);` — positional-field struct shape. Today
`parse_struct_decl` (line ~2835) expects `struct NAME { ... }`
with brace-then-named-fields. The paren-then-positional shape
is rejected with NR020.

### Forward-roadmap

Sub-case 1: extend `parse_match_struct_binding_block` to call
back into `parse_match_one_pattern` for each field's binding —
recursive descent. Smallish ship, can be shipped on a parse-
extension cycle.

Sub-case 2: extend `parse_struct_decl` to accept the paren-form
and synthesize positional field names (`__0`, `__1`, etc.).
Then update field-access path (`p.0`, `p.1`) to resolve to
the synthesized names. Forward-roadmap.

## Adopter migration

```nucleor
// Sub-case 1 — pre-fix:
match l {
    Line { a: Point { x, y: _ }, b: _ } => x,    // ← NR020
}

// Workaround — single-level destructure + manual field access:
match l {
    Line { a, b: _ } => a.x,
}

// Sub-case 2 — pre-fix:
struct P(i64, i64);    // ← NR020

// Workaround — named-field form:
struct P { x: i64, y: i64 }
let p: P = P { x: 1, y: 2 };
```

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
