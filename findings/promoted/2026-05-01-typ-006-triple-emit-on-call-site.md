---
title: `error[TYP-006]: argument type mismatch in call to 'X'` fires THREE TIMES at the same line:column for one call site. Sister to MATCH-001/TYP-001 dual-emit (closed v0.5.18) — same dedup hazard family.
severity: cosmetic dedup gap (UX — adopter sees triple error wall)
probe_file: probes/types/typ006_dedup.nr (probe-branch)
diagnostic_actual: pre-fix — 3× identical `error[TYP-006]: …` blocks emitted for one call site.
diagnostic_expected: 1× error block per distinct call site.
discovered_against: main v0.5.25 (probe rebased)
commit: probe (post-rebase) + main 75028d32
status: CLOSED in v0.6.38 via dedup at the emit site (`diag_add_ex` walks existing diags and drops duplicates by `(code, message, fn_name, line, col)` tuple).
---

## Closure (main agent v0.6.38)

`compiler/nucleor_s1_compiler.nr` `diag_add_ex` (line ~8422) —
walks the existing `diags` Vec before pushing the new row; if a
prior row has identical `(code, message, fn_name, line, col)`,
the new diag is dropped (returns the current count without
adding). Structural cosmetic fix that benefits every diagnostic
class — TYP-006, TYP-008, NUM-022, etc. all emit-deduplicate
through the same path.

## Why dedup at the emit site

The triple-emit happens because some type-check passes visit
the same call site through multiple paths (postfix, direct-call
dispatch, generic-bound resolution). Each visit re-runs the
TYP-006 check and re-emits. Refactoring the visit logic to fire
once is risky (one of the visits is the canonical one, the
others are pre-existing call-site hooks). Dedup at the emit
site is bounded, single-line behavior, matches the v0.5.18
MATCH-001/TYP-001 dual-emit closure pattern.

## Smoke validation

Pre-fix output count for the probe repro:

```
$ nucleor build typ006_repro.nr 2>&1 | grep -c "error\[TYP-006\]"
3
```

Post-fix:

```
$ nucleor build typ006_repro.nr 2>&1 | grep -c "error\[TYP-006\]"
1
```

## Promoted

- Fixture: none (cosmetic dedup ship — no negative-fixture
  shape in the existing infra asserts "exactly 1 error block,
  not 3"). Future ship can add a verify step that grep-counts
  emits for one fixture.
- Fix shipped: v0.6.38.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
