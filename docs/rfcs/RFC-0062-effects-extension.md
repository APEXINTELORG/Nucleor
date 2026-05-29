# RFC-0062-effects-extension — G-10 Effect Annotations Framework

**Status:** Phase 2b Active (R3 cloud-side ship 2026-05-08)
**Parent:** RFC-0062 G-10 row (effect annotations)
**Implementation:** `compiler/nucleor_s1_compiler.nr` (`enforce_g10_effects` + helpers)
**Lays groundwork for:** R4 (G-5 + G-7 + G-9) — extends leaf inference

## Summary

Adds a fixed-vocabulary effect-row attribute family on top of Nucleor
fns. Two attributes:

  - `#[effect(E1, E2, ...)]` — declares the fn produces these effects.
  - `#[allow_effect(E1, E2, ...)]` — silences the G-10 diagnostic on
    this fn for the listed effects (intentional escape hatch).

Initial vocabulary (closed set; unknown names are ignored, not flagged
— Phase 3 may promote to a hard error):

  - `frees` — fn (or its callees) frees a heap allocation.
  - `borrows_mut` — fn (or its callees) takes a `&mut` borrow.
  - `may_return_null` — fn may return a null / `None` sentinel.
  - `direct_ffi` — fn (or its callees) reaches a raw FFI surface.

The framework ships three diagnostics (all error severity per Phase 4
promotion; the framework's gate is opt-in so existing code is
unaffected):

  - `EFFECT-G10-UNDECLARED` — body produces effect E and the fn carries
    no `#[effect(...)]` row at all and no `#[allow_effect(E)]` opt-out.
  - `EFFECT-G10-MISSING-ALLOW` — fn HAS `#[effect(...)]` but body
    produces an extra effect E that is missing from the row and not
    silenced.
  - `EFFECT-G10-WRONG-ROW` — fn declares effect E in `#[effect(...)]`
    but the body produces no operation that yields E (over-declaration).

## Inference

Conservative one-hop. Two passes:

  - Pass A — leaf builtins. Hardcoded table inside the compiler
    maps a small set of primitive call names to their effect:
    - `vec_free` / `hashmap_free` / `str_free` → `frees`
    - (R4 will add: extern "C" call → `direct_ffi`; raw-pointer return
      → `may_return_null`; `&mut` arg at call site → `borrows_mut`.)
  - Pass B — call propagation. A call to a same-source fn whose
    `#[effect(...)]` row declares effect E contributes E to the
    caller's produced set.

The propagation is deliberately one-hop. Transitive enrichment (caller
of a caller) is out of scope for the framework ship; chain length 2+
is opaque. Adopters who need transitive coverage today thread the
declaration up explicitly. Phase 3 may add a fixed-point closure.

## Adopter ergonomics

`main` is the canonical sink. A program whose `main` calls into an
effectful subsystem typically wants `#[allow_effect(<E>)]` on `main`
itself — the effect is owned by the program as a whole, not the
language-level fn boundary.

`#[allow_effect(E)]` is also the right answer for tests, examples,
small fixtures, and any case where the effect is intentional and
documented at the call-site rather than via the row.

## Cheap gate

`enforce_g10_effects` returns the diags Vec unmodified when neither
`#[effect(` nor `#[allow_effect(` appears in the source string, AND
when the proper attribute scanner (which skips line comments and
string literals) returns zero pairs. This double-gate keeps the per-
file cost at one `str_contains` for the majority of the existing
fixture corpus. The compiler self-source documents the attribute
family in `is_error_code` and `enforce_g10_effects`, so the textual
hits are real but the proper scanner returns empty — the compiler
self-build is unaffected.

## Diagnostics shape

All three codes go through the standard `diag_add_ex` pipeline:
severity = `error`, checker = `effect`, with the producing fn name as
the location anchor (line + col from `find_linecol_in_source`). The
`is_error_code` registration ensures `own_diag` and the build summary
both treat them as hard failures (Phase 4 lock-in, not info / warning
windows).

## Out of scope for R3

  - Cross-module / multi-file effect propagation. Today the table is
    rebuilt per resolved single-source string, which folds in `import`-
    pulled fns when the resolver inlines them. Cross-module rows that
    travel via separately-compiled object files are R4+.
  - Generic / polymorphic effects (`#[effect(E from arg)]`).
  - `pure` shorthand for `#[effect()]` (empty row).
  - Closure-body effect inference. Closures lower through a separate
    path that does not currently expose the body to the source-text
    scanner.

## R4 hooks

R4 (G-5 + G-7 + G-9) will extend `g10_builtin_leaf_effect` and add a
sibling `g10_call_site_effects` helper that walks call ASTs for
`direct_ffi` (extern "C" callee), `may_return_null` (raw-pointer
return), and `borrows_mut` (`&mut` argument at the call site). The
diagnostic codes and attribute syntax stay stable; only the inference
table grows.

## Acceptance fixtures

Positive (must compile clean):
  - `tests/features/g10_effect_frees_declared_ok.nr` — direct
    `vec_free` declared via `#[effect(frees)]`.
  - `tests/features/g10_effect_allow_silences_ok.nr` —
    `#[allow_effect(frees)]` silences the diagnostic.
  - `tests/features/g10_effect_propagation_ok.nr` — caller declares
    the same effect as its `#[effect(frees)]` callee.

Negative (must error with the named code):
  - `tests/err/err_g10_effect_undeclared.nr` → `EFFECT-G10-UNDECLARED`.
  - `tests/err/err_g10_effect_missing_allow.nr` → `EFFECT-G10-MISSING-ALLOW`.
  - `tests/err/err_g10_effect_wrong_row.nr` → `EFFECT-G10-WRONG-ROW`.
