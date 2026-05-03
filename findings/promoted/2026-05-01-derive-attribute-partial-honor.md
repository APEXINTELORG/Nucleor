---
title: `#[derive(...)]` silently dropped except for `Debug`. `#[derive(Debug, Clone, PartialEq, Eq, Hash, Default, Ord, PartialOrd)]` parses but only `Debug` actually fires; everything else surfaces as TYP-011 / TYP-005 / TYP-006 at distant USE sites (`a == b`, `a.clone()`, `Default::default()`). Translation-fidelity hit.
severity: silent-miscompute (translation-fidelity)
probe_file: probes/parse/rust_syntax_audit/derive_attribute.nr (probe-branch)
diagnostic_actual: pre-fix — `#[derive(...)]` silently consumed; subsequent `==` / `.clone()` / `default()` use sites fail with TYP-011 etc. far from the derive site.
diagnostic_expected: clean lex-time WARNING naming the dropped derives + workaround pointer, so adopters get the early signal at the derive site.
discovered_against: main v0.5.x (probe rebased)
commit: probe (post-rebase) + main HEAD
status: CLOSED in v0.6.26 via lex-time `warning[DERIVE-001]`. Real derive expansion deferred to a post-v0.6 RFC.
---

## Closure (main agent v0.6.26)

`compiler/nucleor_s1_compiler.nr` lex-time `#[...]` consumer —
sister to v0.6.25's `#[cfg(...)]` halt. Detects `#[derive(`,
walks to the closing `)`, and emits `warning[DERIVE-001]` whenever
the derive body is anything other than exactly `Debug`. Build
continues — TYP-011 still fires at use sites for the dropped
derives — but the adopter gets the signal at the derive site
where it's actionable.

## Adopter migration

```nucleor
// Pre-v0.6.26: silent drop, then TYP-011 at use site:
#[derive(Debug, Clone, PartialEq)]
struct P { x: i64 }
let a: P = P { x: 1 };
let b: P = P { x: 1 };
if a == b { ... };   // ← TYP-011: == not defined for P (silent-derive cause hidden)

// v0.6.26 surface:
#[derive(Debug, Clone, PartialEq)]   // warning[DERIVE-001] at LEX, body unchanged
struct P { x: i64 }
// Use sites still TYP-011 — but the warning above tells you why.

// Workarounds:
// (a) Hand-write the equivalent:
//     fn p_eq(a: P, b: P) -> i64 { if a.x == b.x { 1 } else { 0 } }
// (b) `#[derive(Debug)]` alone continues to work cleanly (no warning).
// (c) Wait for the future derive-expansion RFC.
```

## Why warning, not halt

Unlike `#[cfg(...)]` (which actively miscompiles by emitting both
branches), `#[derive(non-Debug)]` is a no-op — the silent drop
itself doesn't break anything until a USE site touches the
missing impl. Halting at the derive site would hard-stop builds
for adopters who never use the dropped derives (e.g., translated
Rust code where `#[derive(Clone)]` is structural-cargo). Warning
preserves build-through while still naming the issue early.

## No fixture (warning-only ship)

DERIVE-001 fires as a `print()` warning, not a hard halt. There's
no negative-fixture pattern that asserts a warning text without
also asserting a build-failure exit code, so this ship doesn't
add a fixture. The next probe sweep can verify the warning text
appears for any `#[derive(non-Debug)]` source.

## Forward-roadmap (real derive expansion)

Auto-implementing `PartialEq`, `Eq`, `Hash`, `Clone`, `Copy`,
`Default`, `Ord`, `PartialOrd` for user structs requires:

- A typed-AST hook between resolve and lower that, for each
  marked struct, synthesises the appropriate `impl` block.
- Per-derive policy: `Clone` walks fields recursively, `Hash`
  needs a hasher type, `Default` needs `Default::default()` to
  exist for each field type, `PartialOrd` is lexicographic, etc.
- A trait-system surface mature enough that the synthesised
  impls participate in normal trait resolution.

Substantial RFC. Deferred to a post-v0.6 cycle alongside
RFC-0034 `[]` params (which together unlock most of the Rust
derive surface for translation work).

## Promoted

- Fixture: none (warning-only ship — see above).
- Fix shipped: v0.6.26.
- Promoted: 2026-05-02 NIGHT by main agent (probe commit on
  `origin/probe/exploration`).
