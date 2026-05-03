---
title: v0.6.21 closes the `static` decl silent-acceptance hole. Probe matrix shows FOUR sister decl shapes still silently accept at parse and break (or no-op) downstream — (1) `type Name = i64;` accepted but never resolves at use sites (TYP-006); (2) `mod h { fn f() {} }` accepted but `h::f()` rejects with "unsupported associated-fn call" while `f()` (unqualified) works (transparent grouping); (3) `union U { a: i64, b: f64 }` accepted but `U { a: 42 }` rejects with "unknown struct U"; (4) `use std::collections::HashMap;` accepted as a no-op.
severity: silent-acceptance + late-confusing-error (sister to the v0.6.21 static-decl finding pattern)
probe_file: probes/types/module_scope_decl_silent_noop_gaps.nr (probe-branch)
diagnostic_actual: see "Repro matrix" — each gap surfaces as a different downstream error
diagnostic_expected: clean halt at decl OR proper implementation
discovered_against: main v0.6.21 (probe rebased)
commit: probe (post-rebase) + main 2922d604
status: PARTIAL CLOSE in v0.6.50 — `union` halt shipped. The other three sub-gaps are intentional design today (see "Per-shape disposition" below).
---

## Closure (main agent v0.6.50)

### `union` — halt shipped

`compiler/nucleor_s1_compiler.nr` parse_program loop (~line 3542)
now matches `union` (kind-1 identifier) and halts with the static-
decl-precedent diagnostic. Adopters who paste a Rust `union U`
declaration get a clean error pointing at the workaround: model
the union shape with an `enum` (Rust-canonical for tagged unions)
or a struct covering the largest variant.

Verify lock: `tests/err/err_module_scope_union.nr`.

### Per-shape disposition (other 3 sub-gaps)

**`mod helpers { ... }`** — INTENTIONAL TRANSPARENT GROUPING.

The source preprocessor at line ~24098 detects `mod foo {`,
strips the opener and matching `}`, and inlines the inner items
into module scope. That's the documented v0.2.340 (T1.5a)
behavior, with a smoke test at
`tests/smoke/t15a_mod_block_form.nr`. `helpers::f()` rejects
because there's no `helpers::` namespace; `f()` works because the
inner items were hoisted. The probe characterized this as silent-
accept; in fact it's documented inlining. Adding a parse-time
halt would break the smoke test and any user code that already
relies on the inline pattern.

**`use std::collections::HashMap;`** — INTENTIONAL NO-OP.

Same source-preprocessor file (line ~24089). `use <PATH>;` is
recognized and pass-through. HashMap, Vec, str, etc. are global
runtime types, so the `use` line is informational at best and
harmless at worst. A user-defined path (`use my_module::foo;`)
would fail at the use site if `foo` isn't already in scope —
that's a real but distinct gap (named-import resolution), tracked
separately as a v1+ feature.

**`type Name = i64;`** — DECLARED-NOT-RESOLVED.

`parse_type_alias_decl` (line ~2344) creates a kind-51 node for
the alias, but the type-resolver doesn't substitute the alias at
use sites — TYP-006 fires when `Name` is used as a type. Adding
a parse-time halt would block the alias path entirely; the right
fix is to wire alias resolution into `nr_type_to_llvm` and
`type_expr`. That's a larger ship, deferred for a dedicated cycle.
No fixture in the codebase uses `type X = ...` today (verified
via grep), so the user impact is bounded.

## Adopter migration

Pre-v0.6.50 `union` users:

```nucleor
// Pre-fix (silent at parse, "unknown struct" at use):
// union U { a: i64, b: f64 }
// let u: U = U { a: 42 };

// v0.6.50 workaround (clean halt; Rust-canonical enum form):
enum Tagged { IntCase(i64), FloatCase(f64) }

// Or struct-with-bit-pattern-reuse:
struct Raw { bits: i64 }   // both i64 and f64 fit in 64 bits
```

For `mod` block-form: keep using it; the inlining is intentional.
Drop `path::name` qualifiers (use unqualified `name`).

For `use`: drop the `use` line entirely; runtime types are
already in scope.

For `type` aliases: substitute manually until the resolver-layer
ships.

## Promoted

- New fixture: `tests/err/err_module_scope_union.nr` (auto-picked-
  up by tests/err walker).
- Fix shipped: v0.6.50 (union halt).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
- Sister sub-gaps (mod, use, type) documented above as intentional
  design / forward-roadmap.
