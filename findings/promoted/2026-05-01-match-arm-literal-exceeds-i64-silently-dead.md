---
title: Match-arm literal that exceeds i64::MAX is silently accepted; the arm is dead-code (never matches) without warning
severity: silent-miscompute (dead-arm + missing diag)
probe_file: probes/match/arm_literal_overflow_i64.nr (probe-branch)
diagnostic_actual: pre-fix — build succeeds; arm with literal `9223372036854775808` (i64::MAX + 1) never reached
diagnostic_expected: NUM-021 at parse OR MATCH-NNN unreachable-arm warning
discovered_against: main v0.5.17 (probe 050f51d)
commit: probe 050f51d + main 736d88a
status: DOC-ONLY — sister to NUM-021 family. The lexer-level NUM-021 catches > u64::MAX; the gap is in (i64::MAX, u64::MAX] decimal literals, which the lexer stores as i64::MIN bit pattern. Adding a match-arm-specific check requires either source-text recovery at parse_match_one_pattern (no source param today) or a token-level overflow flag that propagates to pattern-parse. Both are non-trivial; bundled with the broader NUM-021 coverage workstream.
---

## Closure (analysis-only — no compiler change)

The lexer's NUM-021 (line ~555) checks decimal literal vs
u64::MAX. For `9223372036854775808` (= 2^63, i64::MAX + 1, but
< u64::MAX), the check passes. The lexer wraps to i64::MIN
when storing in the i64 token slot.

The match-arm pattern parser at line ~1271 reads the i64 value
via `pkv(tokens, cp)`. For a positive literal that wrapped to
i64::MIN, the parser sees `lo_val = -9223372036854775808` and
matches against scrutinees with that value — for an i64
scrutinee like `i64::MAX`, the comparison `i64::MAX == i64::MIN`
is always false, so the arm is dead.

### Why deferred

The fix needs source-text or a token-overflow-flag at pattern-
parse time. Two tractable shapes:

1. **Token flag**: lexer marks tokens whose decimal value was
   in (i64::MAX, u64::MAX]. parse_match_one_pattern checks the
   flag and emits a clean diag.
2. **Source recovery**: parse_match_one_pattern receives source
   string (extra param), reads the original literal text, runs
   the check.

Neither is a one-line change. Bundled with the broader NUM-021
coverage work.

### Sister findings (same workstream)

- `2026-05-02-num-021-coverage-gaps-u64-imin-shift-divzero`
  (gap 1 = u64 const overflow, gap 3 = const div/mod/shift —
  same family of unsigned-context arithmetic gaps).
- `2026-05-02-u64-overflow-silently-wraps` (runtime u64
  arithmetic — sister to gap 1).

## Adopter migration

```nucleor
// Pre-fix (silent dead arm):
let x: i64 = 9223372036854775807;
let r: i64 = match x {
    9223372036854775808 => 1,    // ← always dead
    _ => 0,
};
// r == 0; the arm with 2^63 NEVER fires.

// Workaround (use the canonical i64::MAX):
let r: i64 = match x {
    9223372036854775807 => 1,    // i64::MAX
    _ => 0,
};
// r == 1.
```

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
