---
title: Multiple canonical Rust syntactic forms produce non-actionable diagnostics (NR020 generic parse-error or TYP-005/TYP-008 wrong-error) instead of "feature X not supported in v0.5"
severity: wrong-error / translation-fidelity audit (multi-row)
probe_file: probes/parse/rust_syntax_audit/*.nr (probe-branch)
diagnostic_actual: varies per row — see audit table in finding
diagnostic_expected: clean v0.5/v0.6-boundary diagnostic naming the unsupported feature with workaround
discovered_against: main v0.5.25 (probe rebased)
commit: probe (post-rebase) + main 2fe41ef
status: DOC-ONLY — partial closes already shipped (unit-struct-semicolon catches at parse, char-literal lex extension shipped, etc.). The remaining rows are the v0.6 → v1 parse-extension surface; each is a small ship in isolation but bundled they're a multi-row audit cycle. Forward-roadmap: per-row fixes shipped opportunistically as the parse-extension cycle progresses.
---

## Closure (analysis-only — multi-row audit)

The probe assembled an audit table of 10+ canonical Rust shapes
that produce wrong-class diagnostics today. Per-row status as of
v0.6.51:

| Row | Status | Notes |
|---|---|---|
| `struct U;` (unit-struct semi) | OPEN | NR020 today; clean halt is forward-roadmap |
| `struct Pair(i64, i64);` (tuple struct) | OPEN | NR020; bundled with nested-struct-pattern finding |
| `let c: char = 'a';` (char lit) | PARTIAL | char literals lex; type system maps to i64 for the codepoint |
| `let s: str = r"raw";` (raw string) | CLOSED v0.6.58 | clean lex halt with workaround pointer; full no-escape mode is forward-roadmap |
| `let b = b"hello";` (byte string) | CLOSED v0.6.58 | clean lex halt with workaround pointer; byte-buffer literal sugar is forward-roadmap |
| `let Point { x, y } = p;` (struct destructure-in-let) | OPEN | TYP-008 today; let-pattern destructure not yet wired |
| `<S as Foo>::f(&s)` (UFCS) | OPEN | NR020 today; UFCS forward-roadmap |
| `let r = loop { break 42; };` (break-with-value) | CLOSED v0.6.57 | clean parse halt with workaround pointer; full lowering is v1 loop-as-expression |
| `unreachable!()` macro | CLOSED v0.6.56 | expands to `panic("internal error: entered unreachable code")` matching Rust's std::macros::unreachable! shape |
| `for (k, v) in &m` (tuple destruct in for) | CLOSED v0.6.59 | clean parse halt with workaround pointer (`kv.0`/`kv.1` body destructure) |
| `const fn double(x: i64) -> i64` | CLOSED v0.6.55 | clean parse halt with workaround pointer; full const-eval is v1 |

### Closed sister gaps (already in v0.6.x)

- Unit-struct-semicolon (the v0.6.x precedent) — separate finding
  shipped.
- `cfg(...)` attribute (v0.6.25 — clean halt with workaround).
- `derive(...)` partial (v0.6.26 — clean diag).
- `#[isr]` propagation gaps (v0.6.31, v0.6.32).
- `static` decl at module scope (v0.6.21 — clean halt).
- `union` decl at module scope (v0.6.50 — clean halt).
- Where-clause + impl-block parse fixes (v0.6.46).

### Forward-roadmap

Each remaining row is small in isolation. Tackling them as a
batch in a dedicated parse-extension cycle (with shared parse_*
helpers and consistent diag wording) is the most efficient
path. Bundled with the broader v1 parse-extension workstream.

## Promoted

- No code change in this batch.
- Per-row closes shipped opportunistically as the parse-
  extension cycle progresses.
- Promoted: 2026-05-03 by main agent.
