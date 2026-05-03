---
title: v0.6.11 closes `where T: Trait` on **fn decls** but `where T: Trait` on **struct decls** and **impl blocks** both NR020-panic at parse time. Canonical Rust shapes `struct Wrapper<T> where T: Show { ... }` and `impl<T> Foo for T where T: Show { ... }` reject with `error[NR020]`.
severity: parse-rejection / canonical-rust-shape (Track Y v0.6.11 closure half-done)
probe_file: probes/types/where_clause_struct_and_impl.nr (probe-branch)
diagnostic_actual: pre-fix — NR020 at `where` token (or at the `T` inside `impl<T>`).
diagnostic_expected: accept the where-clause and the impl-level generic-param list.
discovered_against: main v0.6.11 (probe rebased)
commit: probe (post-rebase) + main c09883d7
status: CLOSED in v0.6.46 — parse_struct_decl / parse_impl_block now skip where-clauses; new `skip_balanced_angle` consumes the `impl<T>` generic-param list. Bounds not yet wired (forward-roadmap).
---

## Closure (main agent v0.6.46)

`compiler/nucleor_s1_compiler.nr`:

### parse_struct_decl

Added `cp = skip_where_clause(tokens, cp);` between gparams and
the `{` so canonical Rust struct decls with where-clauses parse
cleanly. The bounds are skipped, not stored on the struct AST
yet — forward-roadmap.

### parse_impl_block

Two changes:

1. New `skip_balanced_angle` call at the head consumes the impl-
   level `<T, U, ...>` generic-param list. The existing
   `skip_angle_group` requires the trailing context to be a
   type-position token (`(`, `{`, `::`); it fails for `impl<T>
   A` where the trailing context is an ident (the trait name).

2. `cp = skip_where_clause(tokens, cp);` between the impl-target
   type and the `{` so `impl X where T: Show { … }` parses.

### New helper `skip_balanced_angle`

Mirrors `skip_angle_group` but without the trailing-context
guard. Walks `<...>` matching depth, returns position past `>`
or unchanged if unbalanced.

## Adopter migration

```nucleor
trait A { fn a(self: &Self) -> i64; }
struct X { v: i64 }
impl A for X { fn a(self: &X) -> i64 { self.v + 1 } }

// All three previously NR020'd; v0.6.46 parses cleanly:
struct Wrapper<T> where T: A { inner: T }
impl<T> X { fn passthrough(self: &X) -> i64 { self.v + 2 } }
impl<T> X where T: A { fn p2(self: &X) -> i64 { self.v + 3 } }
```

## Forward-roadmap (bound enforcement)

The where-clause and impl<T> generic-param list are parsed-and-
skipped. The bounds aren't yet:
- Stored on the struct/impl AST node.
- Used during method-call dispatch.
- Type-checked at use sites.

Wiring bounds end-to-end is a substantial RFC. For now, the
parse acceptance unblocks adopters running canonical Rust
sources through translation.

## Promoted

- Fixture: `tests/features/v0646_where_clause_struct_impl.nr`
  (positive — exercises struct where, impl<T>, and impl<T> +
  where together).
- Fix shipped: v0.6.46.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
