# RFC-0045 — Restore `@differentiable` Attribute

**Status:** Draft (drift restoration — V1.14)
**Date:** 2026-05-03
**Predecessor:** Nucleor V2 had `@differentiable` as a parsed AST attribute on fn declarations. OSS dropped it (zero matches).

## Motivation

The `autodiff` rod (reverse-mode AD with full elementary suite + tape reset + checkpointing) is shipped and works. Adopters using it write differentiable fns by convention; nothing in the type system marks which fns are safe to differentiate. Three problems:

1. **Discovery:** no way to grep for "all differentiable fns" in a codebase.
2. **Validation:** the type-checker can't warn when a `@differentiable` fn calls a non-differentiable helper (e.g. an I/O op or non-smooth integer cast).
3. **Tooling hooks:** future LSP / `nuc summary` / docs surface need a marker to display.

V2 had the parsed annotation but no semantic enforcement. This RFC restores at the same fidelity: parser + AST + emit-as-metadata. Semantic enforcement (call-graph walk verifying every callee is also `@differentiable`-tagged) is deferred to a follow-on ship.

## Design

- Parser: `@differentiable` as a fn-decl attribute (sister to `@hot`, `@const_fn`, `#[no_alloc]`). Parsed at line ~280 of `compiler/nucleor_s1_compiler.nr` in the attribute-skip loop. Stored on the fn AST node (kind-30).
- Codegen: emits `__nucleor_diff_<fn_name>` symbol alias for the autodiff runtime to discover differentiable fns at link time. Existing `autodiff` rod calls switch from string-name lookup to symbol-table dispatch.
- Type-check: parses cleanly, no errors. (Semantic call-graph enforcement is RFC-0045b — deferred.)

## Cost

~50 LOC for parse + AST emit + symbol alias. No type-check work.

## Hot-path risk

None. Attribute is metadata-only; doesn't touch any hot lower path.

## Forward-roadmap

The semantic enforcement pass (every callee must also be `@differentiable`) is V1.6-class — sister to no-alloc / no-panic call-graph propagation. Defer.

## Closure criteria

- `@differentiable fn loss(x: f64) -> f64 { ... }` parses without warning.
- Symbol alias `__nucleor_diff_loss` emitted in IR.
- `autodiff` rod can discover differentiable fns via symbol table.
- Round-2 self-host fixed-point holds.
