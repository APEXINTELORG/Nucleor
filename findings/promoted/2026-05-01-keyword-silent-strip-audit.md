---
title: Multiple Rust keywords silently stripped or misparsed — `unsafe`, `'static`, `where T: NoSuchTrait`, plus a `move` closure clang-link failure with `@move undefined`
severity: silent-miscompute family (semantic mismatch with Rust)
probe_file: probes/async/keyword_strip_audit.nr (probe-branch)
diagnostic_actual: per-keyword breakdown in finding
diagnostic_expected: parse-time rejection naming each unsupported keyword + workaround
discovered_against: main v0.5.17 (probe 0f8a164)
commit: probe 0f8a164 + main 736d88a
status: CLOSED — all 4 sub-cases shipped or verified-already-closed. `unsafe fn` halt v0.6.53. `move` closure halt v0.6.62. `where T: NoSuchTrait` covered by v0.4.130 trait-bound NAME verification (re-tested v0.6.67). `'static` lifetime works cleanly via lifetime-aware parse_type path (re-tested v0.6.67).
---

## Closure (analysis-only — no compiler change)

Per-keyword status:

### 1. `unsafe fn` — silently stripped

Adopters porting `unsafe fn dangerous() -> i64 { 42 }` get a
silent-strip of `unsafe`, the `fn dangerous` parses normally
without the marker. No actual unsafe-block semantic in v0.6
anyway (no checked operations to opt out of), but the silent
strip removes the visual signal in audits.

Forward-roadmap: emit a `print + panic` halt at parse_program
when `unsafe fn` is detected (kind-1 "unsafe" identifier
followed by kind-10 fn token).

### 2. `'static` lifetime — VERIFIED OK as of v0.6.67

Re-tested 2026-05-03: `let s: &'static str = "hello"; print(s);`
compiles and runs cleanly. The lifetime tokens (`'static`, `'a`,
etc.) are skipped by the lifetime-aware path in parse_type
(`& 'lifetime T` shape) so the canonical Rust form works.

### 3. `where T: NoSuchTrait` — VERIFIED CLOSED by v0.4.130 (re-tested v0.6.67)

The v0.4.130 trait-bound NAME verification (line ~18495)
covers both `<T: Trait>` and `where T: Trait` forms because
`parse_where_clause_into_gparams` splices `?Bound` markers into
the same gparams list that the v0.4.130 walker iterates. Tested
2026-05-03: `fn f<T>(x: T) -> i64 where T: NoSuchTrait { ... }`
fires `error[TYP-019]: trait bound ... references unknown trait
'NoSuchTrait'` cleanly.

### 4. `move` closure — CLOSED v0.6.62

```nucleor
let f = move || x + 1;    // pre-v0.6.62: clang-link error '@move undefined'
                          // v0.6.62: clean parse halt with workaround
```

`parse_primary` now detects `move` (kind-1 ident) followed by `|`
(token 65) or `||` (token 37) and halts with a clean diag pointing
at the workaround (drop the `move` — v0.6 closures capture
references to the enclosing scope which is observably the same as
Rust's move for the i64-everywhere ABI). Forward-roadmap: when v1
borrow-checker arrives, `move` will gain meaning.

Regression-lock: `tests/err/err_move_closure.nr`.

### Existing close (v0.6.x partial)

- v0.6.27/28: `unsafe { }` block form catches at parse-time as
  a passthrough (matching the wrapping/unsafe sister at line
  ~17468).
- v0.6.46: where-clause skipper accepts arbitrary syntax
  (deliberately permissive to ease translation).

## Forward-roadmap

A keyword-audit ship cycle would land 4 distinct halts:
- `unsafe fn` → parse halt with workaround (drop `unsafe`).
- `move` closure → lex-time detection + clean halt.
- `where T: NoSuchTrait` → trait-name validation in where-clause.
- `'static` lifetime — handled today; just doc-only.

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
