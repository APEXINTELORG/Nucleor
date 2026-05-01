---
title: Non-exhaustive match emits BOTH `TYP-001` and `MATCH-001` with identical text — adopter sees the same diagnostic twice
severity: cosmetic / wrong-error display (sibling to NUM-003 dup family)
probe_file: probes/match/non_exhaustive_dup_diag.nr (will be filed)
diagnostic_actual: two `error[...]` lines with identical text and source location, differing only in the diag code
diagnostic_expected: one diagnostic; pick MATCH-001 (subsystem-specific) and suppress TYP-001 fall-through, OR pick TYP-001 (umbrella) and remove the MATCH-001 dispatch — whichever has the better adopter UX
discovered_against: main v0.5.17 (probe rebased afbd8be)
commit: probe afbd8be + main 736d88a
---

## Repro

```nr
enum Color { Red, Green, Blue }

fn name(c: Color) -> str {
    match c {
        Color::Red => "red",
        Color::Green => "green",
    }
}

fn main() -> i32 { print(name(Color::Blue)); 0 }
```

## Actual

```
error[TYP-001]: non-exhaustive match: 2 arms for enum with 3 variants. Workaround: add a `_ => default_value,` arm or list every variant explicitly.
  --> fn name@line 4:5
  |
4 |     match c {
  |     ^

error[MATCH-001]: non-exhaustive match: 2 arms for enum with 3 variants. Workaround: add a `_ => default_value,` arm or list every variant explicitly.
  --> fn name@line 4:5
  |
4 |     match c {
  |     ^
```

Same line, same column, same text — only the code prefix differs (`TYP-001` vs `MATCH-001`). Adopter scrolls past one or hand-fixes their match exhaustiveness, then re-runs and sees the second diagnostic still there (because the same bug). Or — more likely — they fix it and BOTH diagnostics resolve at once.

## Sister double-emit hazards

This is the third double-emit hazard observed:
1. `2026-04-30-num-003-duplicate-warning-in-fnarg.md` — NUM-003 dup at multi-pass arg-typing (DEFERRED — needs cast-level diag location)
2. ATOMIC-003 emits twice (`Cell<` + `cell_new`) for the same Cell-in-#[atomic] case (cosmetic, observed in earlier sweep — not filed because two distinct messages)
3. MATCH-001 + TYP-001 (this finding)

The pattern: type-check has multiple checking subsystems; each detects the same hazard via a different rule. Without a "diag-suppression-hierarchy", multiple subsystems each emit.

## Suspected fix

Pick whichever diagnostic has the better message + remove the other:

**Option A** (recommended): keep `MATCH-001` (subsystem-specific, more discoverable for adopters scanning by category). Remove the TYP-001 emit at the match-exhaustiveness check site — it's a fall-through that hits both passes.

**Option B**: keep `TYP-001` (umbrella for type errors). Remove the MATCH-001 emit. Less specific but matches the broader TYP-* convention.

In both cases the dedup is at the emit site, not at the diagnostic-printer level.

## Severity

Cosmetic. The diagnostic text is correct. Adopter resolves the bug from either message. The double-emit is just visual noise.

## Cross-ref

- 2026-04-30-num-003-duplicate-warning-in-fnarg.md — sister double-emit hazard, deferred
- ATOMIC-003 (Cell-in-#[atomic]) — also double-emits but for two distinct keywords (Cell< and cell_new); arguably correct as separate messages
- v0.5.7-9 era closures — main agent has been actively addressing match-related hazards

## Probe

Filed alongside this finding.


## Promoted

- Fix shipped: v0.5.18 — drop TYP-001 emit at both sites in
  s1's match exhaustiveness check (line ~12517 expression
  context, line ~12880 statement context). Only MATCH-001 fires
  now; same diagnostic text, same line/col, single emission.
- TYP-001 explain entry retained so adopters with legacy docs
  / scripts can still `nuc explain TYP-001` and learn it's been
  unified. Both `nucleor_tools_suite.nr` registry entries
  updated to mark TYP-001 as "no longer emitted".
- Validation: probe-agent's repro now emits 1 MATCH-001 instead
  of 1 TYP-001 + 1 MATCH-001 with identical text. Round-2 IR
  fixed-point holds.
- Sister double-emit hazards still open:
  - 2026-04-30-num-003-duplicate-warning-in-fnarg (DEFERRED in
    finding doc — needs cast-level diag location).
  - ATOMIC-003 on Cell-in-#[atomic] (cosmetic, not yet filed).
- Promoted: 2026-05-01 by main agent (probe commit afbd8be).
