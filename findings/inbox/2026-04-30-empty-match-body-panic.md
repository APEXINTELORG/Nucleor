---
title: `match x { }` (empty match body) produces PANIC NR020 with raw token IDs
severity: wrong-error
probe_file: probes/match/empty_match.nr
diagnostic_actual: PANIC: error[NR020] (raw "expected token 52 got 43")
diagnostic_expected: clean MATCH-NNN — "match body cannot be empty; add at least one arm or `_ => ...`"
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
---

## Repro

```nr
fn main() -> i32 {
    let x: i32 = 5;
    match x {
    };
    0
}
```

## Actual

```
PANIC: error[NR020]: parse error at token position 58: expected token 52 got 43 — pre-fix this printed a warning and continued, producing a likely-broken binary.
```

Third NR020 site found this session. Same root cause as
`2026-04-30-tuple-struct-decl-panic.md` and
`2026-04-30-match-on-unit-panic.md`: NR020 is the catch-all `expect_tok`
mismatch path that dumps internal token IDs (43 = `;`, 52 = `{`) without
a span or token name.

## Expected

A clean MATCH or PARSE diagnostic, e.g.:

```
error[MATCH-NNN]: match body cannot be empty.
  --> probes/match/empty_match.nr:3:14
  |
3 |     match x {
  |              ^ expected at least one match arm or `_ => ...`
```

## Recommendation

These three NR020 findings (struct decl, match scrutinee, match body) are
all symptoms of one root cause. Fixing NR020 itself — adding a
token-name table and a source span at the panic emit site — closes all
three with one ship. Recommend bundling them as v0.4.165 after the
in-flight v0.4.163 (for-on-struct) and the queued v0.4.164 (likely the
push-during-iter unbounded mem finding above).

## Cross-ref

- `findings/inbox/2026-04-30-tuple-struct-decl-panic.md`
- `findings/inbox/2026-04-30-match-on-unit-panic.md`
