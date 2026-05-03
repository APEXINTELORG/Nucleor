---
title: TYP-026 ("fn missing tail expression") fires for `let _ = body;` but NOT for the equivalent `body;` (raw expr-stmt with trailing semi) — incomplete coverage of the value-discarded shape.
severity: silent-miscompute coverage gap (TYP-026 family hole)
probe_file: probes/numeric/fn_missing_tail_semi_only.nr (probe-branch)
diagnostic_actual: pre-fix — `fn add(a: i64, b: i64) -> i64 { a + b; }` builds clean and silently returns 5 (the body's value flowed through despite the trailing semicolon).
diagnostic_expected: TYP-026 fires.
discovered_against: main v0.5.17 (probe 050f51d)
commit: probe 050f51d + verified clean against main 6b8bcb50
status: ALREADY CLOSED — closed in v0.6.1 via the `had_semi` flag in `parse_stmt` (line ~2443) which now propagates "trailing semicolon discards value" through to the TYP-026 emit site. Verified at v0.6.36.
---

## Verification (main agent v0.6.36)

Ran the canonical repro from the finding:

```nucleor
fn add(a: i64, b: i64) -> i64 { a + b; }
fn main() -> i32 { print_int(add(2, 3) as i32); 0 }
```

Output: `error[TYP-026]: fn 'add' declared to return 'i64' but
body's last statement is a 'let' or assignment that discards its
value …`. Build halts. Same diag as the `let _ = a + b;` form.

The diag wording mentions "let or assignment" but the v0.6.1
`had_semi` flag actually fires on any expr-stmt-with-trailing-
semi shape — the wording was kept for backward compatibility
with the v0.4.219 era diag string. Future cosmetic ship can
broaden the wording to "discarding statement (let / assignment /
expr-stmt with trailing semi)".

## No fixture added (already closed)

A positive fixture for the now-closed gap would duplicate
`tests/err/err_typ_026_tail_expr_with_semi.nr` (added in v0.6.1).
No new fixture needed.

## Promoted

- Fix shipped: v0.6.1 (had_semi flag in parse_stmt).
- Fixture (existing): `tests/err/err_typ_026_tail_expr_with_semi.nr`.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
