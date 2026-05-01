---
title: `match () { () => ... }` produces PANIC with raw token IDs, not a user-grade diagnostic
severity: wrong-error
probe_file: probes/casts/match_on_unit_literal.nr
diagnostic_actual: PANIC: error[NR020] (raw "expected token 51 got 52")
diagnostic_expected: clean PARSE-NNN with span pointing at the `(` after `match`, OR a TYP-NNN saying scrutinee type `()` (unit) is not supported
discovered_against: v0.4.162
commit: a99fc717079b8f7774c8ddf7aa03a4cc5e132eae
status: CLOSED in v0.4.208 — same fix as tuple-struct-decl-panic. NR020 now reports `expected backtick ) backtick, got backtick { backtick` instead of `expected token 51 got 52`. Unit-as-scrutinee is still rejected (intentional) but the diagnostic is actionable.
---

## Repro

```nr
fn main() -> i32 {
    match () {
        () => print_int(42),
    };
    0
}
```

## Actual

```
$ ./bin/nucleor.exe build probes/casts/match_on_unit_literal.nr -o match_on_unit_literal
  source: probes/casts/match_on_unit_literal.nr (78 bytes)
  mode: fast (ownership + type)
PANIC: error[NR020]: parse error at token position 32: expected token 51 got 52 — pre-fix this printed a warning and continued, producing a likely-broken binary.
```

Same PANIC NR020 surface as `2026-04-30-tuple-struct-decl-panic.md` (different syntactic site, same diagnostic class). The compiler exits non-zero, so no silent miscompile, but the diagnostic exposes raw token IDs (51 = `)`, 52 = `{`) with no source span and a misleading "pre-fix" tail.

## Expected

Either:
- A user-grade PARSE diagnostic naming the unsupported construct (e.g. unit literal `()` as match scrutinee, OR unit pattern `()` as match arm), with a span, OR
- If unit-typed match is on the v0.4 punchlist, accept it and produce a runtime that prints `42` and exits 0.

## Suspected location

NR020 looks like the catch-all `expect_tok` mismatch path. Same root path as the tuple-struct-decl finding — anywhere `expect_tok(...)` falls through, the user gets a raw "expected token N got M" string. Two manifestations in one probe sweep suggests this is the dominant failure mode for unsupported syntax. A single fix that gives every `expect_tok` site a token-name table (`52 → "{"`, `51 → ")"`, etc.) plus a span would close many wrong-error findings at once.

The specific call site for this match parse is somewhere in the `match` expression parser (grep `parse_match` / token 32 = `match`?). I did not chase it further to keep this finding focused.

## Cross-ref

- See `findings/inbox/2026-04-30-tuple-struct-decl-panic.md` — same NR020 class, different repro (struct decl vs match scrutinee).


## Promoted

- Status frontmatter: see top of file. Closure version: **v0.4.208**.
- Verify gate: existing per-feature loop picks up the fixture above.
- Promoted: 2026-04-30 by main agent (footer backfilled 2026-05-01 per probe-agent Q3 footer-shape uniformity request).
