# RFC-0044 — Per-BinOp `OverflowMode` Field

**Status:** Draft (drift restoration — V1.13)
**Date:** 2026-05-03
**Predecessor:** Nucleor V2 carried `OverflowMode { Trap | Wrap | Saturate }` as a per-`BinOp` IR field, alongside the block-form syntax (`wrapping{}`/`saturating{}`/`checked{}`). OSS retained only the block form.

## Motivation

Block-form is coarse-grained: every arithmetic op inside a `wrapping{}` block uses wrapping semantics. There's no way to write a single expression that mixes:
- intentional wrapping for one op (e.g. hash mixing)
- saturation for another (e.g. clamping ADC output to i16 range)
- trap-on-overflow for a third (e.g. monetary calculation)

Adopters today have to nest blocks awkwardly:
```nucleor
saturating { let clamped: i16 = wrapping { hash * mix } as i16; };
```
when the per-op form is more direct:
```nucleor
let clamped: i16 = (hash *#wrapping mix) as#saturating i16;
```
(syntax sketch only; the wire form below is more conservative.)

## Design

The IR-level change is the load-bearing one: add `overflow_mode: OverflowMode` to BinOp / Cast IR nodes. The default mode reads from the surrounding block context (preserving today's behavior — no source change needed for existing code).

For source-level surface, two opt-in forms:

1. **Inline-suffix arithmetic op** (post-fix marker): `a *#wrap b`, `a +#sat b`, `a /#trap b`. Disambiguates per-op without nesting.
2. **Inline-suffix cast**: `expr as#sat i16`, `expr as#trap u32`.

Both forms compose with surrounding block context — the inline marker overrides for that op only, the surrounding block re-asserts for everything else.

## Implementation

- Parser: `*#sat` lexes as a single token (avoids ambiguity with `*` followed by a `#[attr]`). New token kind `BINOP_WITH_MODE`.
- AST: kind-4 (binop) gains an optional `mode: i64` field (encoded as 0=default, 1=wrap, 2=sat, 3=trap).
- Type-check: mode propagates to width-check rules (e.g. saturating cast clamps at type boundary; wrapping cast truncates; trapping cast emits panic-on-overflow IR).
- Lower: existing block-form path stays. New per-op path emits the matching helper directly.

## Cost

~150 LOC compiler-side. Reuses existing `wrapping_*` / `saturating_*` / `panic_*` runtime helpers — no new runtime work.

## Hot-path risk

None. The new field is optional; default-mode binops emit the same IR they do today.

## Closure criteria

- `let r: i16 = (hash *#wrap mix) as#sat i16;` lowers to wrapping mul + saturating cast.
- Mixing inline-marker with block-form composes correctly (block sets default, marker overrides).
- Round-2 self-host fixed-point holds.
