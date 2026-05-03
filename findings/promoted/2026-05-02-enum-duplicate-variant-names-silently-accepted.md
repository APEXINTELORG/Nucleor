---
title: `enum E { A, A, A }` is silently accepted with all 3 duplicate variants kept distinct (MATCH-001 confirms "1 arms for enum with 3 variants" — Nucleor sees them as separate). Rust rejects with E0428 "the name `A` is defined multiple times". Same for data variants `enum E { Foo(i64), Foo(str) }`. Sister to top-level dup-enum-decl handled by v0.6.27 TYP-041.
severity: silent-miscompute / type-system gap (Rust E0428 not enforced)
probe_file: probes/enums/duplicate_variant_names.nr (probe-branch)
diagnostic_actual: pre-fix — build succeeds; the variants tracked separately. `match E::A { E::A => 1 }` becomes non-exhaustive (matches only ONE of the three), MATCH-001 confirms "3 variants" in the enum.
diagnostic_expected: clean ERROR mirroring Rust E0428: `the name 'A' is defined multiple times` with the conflicting decl-line locations.
discovered_against: main v0.5.31 (probe rebased)
commit: probe (post-rebase) + main d5d5035c
status: CLOSED in v0.6.27 via `error[TYP-040]` at variant-decl in `parse_enum_decl`.
---

## Closure (main agent v0.6.27)

`compiler/nucleor_s1_compiler.nr` `parse_enum_decl` variant-loop:
when adding each variant, walks the existing variant list and
emits `error[TYP-040]` if the variant name is already declared.
Halts with workaround pointer mentioning the `Foo(i64) +
Foo(str)` shape and the `FooInt` / `FooStr` rename pattern.

Sister to v0.6.27's TYP-041 (top-level duplicate enum decl) and
TYP-039 (duplicate field in struct decl) — three sister halts in
one ship covering the dup-decl family for structs and enums.

## Adopter migration

```nucleor
// Pre-v0.6.27 (silent, MATCH-001 fires with wrong arm count):
enum E { A, A, A }
match E::A { E::A => print_int(0) };  // MATCH-001: 1 arms for 3 variants

enum F { Foo(i64), Foo(str) }         // both kept as distinct variants

// v0.6.27 surface:
// TYP-040: duplicate enum variant `A` in `enum E`
// TYP-040: duplicate enum variant `Foo` in `enum F`
//
// Workaround for the typo case: drop the duplicate.
// Workaround for the overload case (Foo(i64)+Foo(str)): rename to
//   distinct variant names (FooInt / FooStr); Nucleor doesn't yet
//   support trait-style overloaded variants.
```

## Promoted

- Fixture: `tests/err/err_typ_040_dup_enum_variant.nr`.
- Fix shipped: v0.6.27.
- Promoted: 2026-05-02 NIGHT by main agent (probe commit on
  `origin/probe/exploration`).
