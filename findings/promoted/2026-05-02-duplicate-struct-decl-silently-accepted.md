---
title: `struct W { … } struct W { … }` (duplicate struct decl) is silently accepted; first decl wins for `W { … }` initialization. `struct P { x: i64, x: i64 }` (duplicate FIELD in decl) also silently accepted at decl-time (TYP-017 only fires at init-site `P { x: 1, x: 2 }`). Sister to enum-duplicate-variant-names finding. Rust E0428 / E0124 catch both at decl-time.
severity: silent-miscompute / type-system gap (Rust E0428 + E0124 not enforced for struct decls / fields)
probe_file: probes/types/duplicate_struct_decl.nr (probe-branch)
diagnostic_actual: pre-fix — build + run succeed; subsequent struct uses resolve to first decl silently. Dup field at decl: TYP-017 only at init-site.
diagnostic_expected: clean ERROR at decl-site mirroring Rust E0428 (`the name 'W' is defined multiple times`) and E0124 (`field 'x' is already declared`).
discovered_against: main v0.5.31 (probe rebased)
commit: probe (post-rebase) + main d5d5035c
status: CLOSED in v0.6.27 via `error[TYP-039]` (dup field at struct-decl) + `error[TYP-041]` (dup top-level struct decl).
---

## Closure (main agent v0.6.27)

`compiler/nucleor_s1_compiler.nr` — sister halts:

- `parse_struct_decl` field-loop: when adding each field, walks
  the existing field list and emits `error[TYP-039]` if the name
  is already declared. Mirrors Rust E0124. Halts at the duplicate
  field, naming both the field and the struct context indirectly
  (the workaround mentions renaming to `x_alt` etc).

- Pass-1 collection (line ~23754): tracks `seen_struct_names_v062`
  (Vec<str>); on each kind-33 node, walks the seen list and emits
  `error[TYP-041]` if the struct name already declared. Mirrors
  Rust E0428. Same shape as the existing duplicate-pub-fn check
  at line ~7389.

Together they cover all 3 repros from the finding (dup top-level
struct same fields, dup top-level struct different fields, dup
field within decl).

## Adopter migration

```nucleor
// Pre-v0.6.27 (silent — first wins):
struct P { x: i64, x: i64, y: i64 }
struct W { v: i64 } struct W { name: str }

// v0.6.27:
//   TYP-039: dup field `x` in struct decl
//   TYP-041: dup struct decl `W`
//
// Workarounds: rename or remove the duplicate. If both shapes are
// wanted (different physical fields with same logical role; or
// version-skew structs across modules), give them distinct names.
```

## Why halt vs warn

Unlike v0.6.26's `#[derive(non-Debug)]` (a no-op until use), dup
struct decl actively causes silent miscompiles — second decl's
fields are unreachable but the source reads as if they exist.
Adopter intent is undecidable from the surface alone (was the
second decl meant to override? to extend? to coexist as a
different type?). Halt + workaround pointer is the right shape.

## Forward-roadmap (more dup-decl families)

Tracked but not in this ship:
- Duplicate `trait` decls — same E0428 family.
- Duplicate `impl Trait for T` blocks — Rust E0119.
- Duplicate `const` / `static` (when statics ship beyond v0.6.21
  parse-time-halt).

## Promoted

- Fixtures: `tests/err/err_typ_039_dup_field_in_struct_decl.nr`,
  `tests/err/err_typ_041_dup_struct_decl.nr`.
- Fix shipped: v0.6.27.
- Promoted: 2026-05-02 NIGHT by main agent (probe commit on
  `origin/probe/exploration`).
