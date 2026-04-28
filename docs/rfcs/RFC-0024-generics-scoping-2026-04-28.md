# RFC-0024 Generic Enums — Implementation Scoping

**Date:** 2026-04-28
**Status:** Scoping (pre-implementation)
**Targets:** v0.4.44 → v0.4.50ish

This doc maps the path from today's hardcoded `Result`/`Option` stubs
to fully generic enum type propagation. It's the design step before
code, since Phase 1 (parser acceptance of `<T, E>`) already shipped
in v0.2.x but Phases 2-4 are multi-day work that needs planning.

## Why this is the keystone

This single workstream unblocks 4 separate downstream items:

1. **v0.2.0.md deferred row #5** — RFC-0016 Phase 4: `From`/`Into` +
   `?` auto-conversion. `From<T>`/`Into<T>` need generic trait params.
2. **v0.2.0.md deferred row #6** — RFC-0018 Phase 2: Resolver
   path-to-symbol with visibility. Symbol-table refactor needs the
   generic-aware type machinery.
3. **v0.2.0.md deferred row #7** — RFC-0018 codegen name mangling
   with module path. Same dependency.
4. **NUC-FEEDBACK-002** — real `Vec<f32>` type propagation. The
   element-type lookup through `vec_get(v, i)` is the same machinery
   as variant-payload-type lookup through `Some(x)` / `Ok(v)`.
5. **RFC-0028 Phase 6+** — user-implementable `Display`/`Debug`
   traits + container `:?`. Recursive Debug-walk needs to know the
   element type in `Vec<T>` / `Option<T>` / `Result<T, E>`.

## Today's state (v0.4.43)

### What works (Phase 1)

- Parser: `parse_enum_decl` (line 1872) accepts optional `<T, E>`
  after enum name; type params stored in AST node field.
- Variant payload types parse via `parse_type` so they CAN reference
  the type params textually (e.g. `Ok(T)` parses as `Ok` with payload
  type `T`).
- Existing untyped `Result`/`Option` stubs work end-to-end as
  `Vec<i32>` `[tag, payload]` cells where payload is always i64.
  Adopters can write `Some(42)`, `None`, `Ok(value)`, `Err(msg)` and
  pattern-match them; payload bindings always get type i64.

### What's hardcoded (the gap)

Search for `"Result"` / `"Option"` in `compiler/nucleor_s1_compiler.nr`:

- **Lines 847-848**: parser hardcodes Some/None → "Option",
  Ok/Err → "Result" without consulting any enum table.
- **Lines 1450-1451, 1527-1528, 2238-2239**: same hardcode in
  match-arm parsing.
- **Lines 9121-9122**: type-checker special-cases Option/Result as
  "skip element-type checking".
- **Lines 9707-9710**: type-compat allows Option/Result/Vec to
  freely substitute for each other (untyped-Vec contract).

These hardcodes were the v0.2 strategy: ship working `Result`/`Option`
without paying for the full generic machinery. RFC-0024 closes them
all by routing through the enum table with type-param substitution.

## Phased implementation plan

### Phase 2 — Constructor type propagation (~v0.4.44 / 1-2 days)

**Goal:** `Ok(value)` infers `value`'s static type as the T parameter.

- Extend `expr_struct_type` (or sibling) so `EnumName::Variant(arg)`
  resolves to `EnumName<inferred_T>` where `inferred_T` is the
  static type of `arg`.
- Add a side-table `__variant_type` keyed by AST node id storing
  the inferred T per call site.
- Existing untyped `Result` / `Option` continue to work; Phase 2 is
  additive — it provides ANNOTATED instances alongside the bare ones.

**Verify pin:** `tests/fixtures/repro_v44_generic_constructor.nr`
asserts `Some(3.14_f64)` is bound as `Option<f64>` and `Some("hi")` as
`Option<str>`.

**Risk:** binding propagation through `let x = Some(value)` needs
sym-table threading. Current `infer_var_type_from_source` is regex-
based; might need extension.

### Phase 3 — Pattern binding type inference (~v0.4.45 / 1-2 days)

**Goal:** `match x { Some(y) => ... }` binds `y` with the type T from
the matched expression's `Option<T>`.

- Extend `parse_match_stmt` arm-binding code to look up the matched
  expression's type, find its enum's type-param substitution, and
  set the binding's symbol-table type to the substituted T.
- Affects 5 hardcoded sites in match parsing (1450, 1527, 2238).

**Verify pin:** `tests/fixtures/repro_v45_pattern_binding.nr`
exercises `Some(f64) → y: f64`, `Ok(MyStruct) → v: MyStruct`.

### Phase 4 — Vec<T> element type propagation (~v0.4.46-47 / 1-2 days)

**Goal:** `vec_get(v, i)` where `v: Vec<f32>` returns `f32` (not i64).

This is the NUC-FEEDBACK-002 close. Same machinery as Phase 3
— `Vec<T>` → element-type lookup through `vec_get` / `vec_first` /
`vec_last` / `vec_pop`.

**Verify pin:** lift the existing `tests/err/err_vec_narrow_float.nr`
from negative-test (TYP-009 hard reject) to positive-test (real
`Vec<f32>` arithmetic produces correct `f32_add` results).

### Phase 5 — Trait generic params (~v0.4.48 / 1-2 days)

**Goal:** `From<T>` / `Into<T>` trait params on `?` operator
auto-conversion. Closes v0.2.0.md deferred row #5.

### Phase 6 — Module-aware symbol table refactor (~v0.4.49-50 / 2-3 days)

**Goal:** RFC-0018 Phase 2 resolver with `pub` visibility enforcement.
Closes v0.2.0.md deferred rows #6 + #7.

## Migration story

Backward compatibility: every existing `Result` / `Option` use must
continue to compile and run identically. The hardcodes in 9707-9710
that allow free substitution between `Option`/`Result`/`Vec` element
types stay until Phase 4 ships — at which point the type-prop
mechanism makes them unnecessary AND catches the real type errors.

## What lands in this sequence

| Phase | Ship | Closes |
|---|---|---|
| 2 | v0.4.44 | (foundation — no deferred row directly) |
| 3 | v0.4.45 | (foundation) |
| 4 | v0.4.46-47 | NUC-FEEDBACK-002 + RFC-0015 strict-mode flip enabler |
| 5 | v0.4.48 | v0.2 deferred row #5 (RFC-0016 `From`/`Into` + `?` conv) |
| 6 | v0.4.49-50 | v0.2 deferred rows #6 + #7 (RFC-0018 resolver + mangling) |

After Phase 6, the only v0.2 deferred rows still open are #1-4
(RFC-0015 Phase 3+5+7 strict-mode bundle), which Phase 4 makes
tractable but doesn't itself complete.

## Coordination notes

- **Bootstrap fixed point** must hold at each phase. Each phase
  ships as its own small fixed-point release.
- **Verify gate** must stay green; any test that depended on the
  untyped Vec<i32>[tag,payload] shape needs an explicit annotation
  or update.
- **Memory + timing** continue to be tracked per protocol.
