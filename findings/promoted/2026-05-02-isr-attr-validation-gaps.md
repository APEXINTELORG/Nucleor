---
title: `#[isr]` attribute validation has three gaps — (a) when placed on a non-fn item (e.g. `struct`), the attribute silently no-ops on the struct AND leaks to the next fn, producing a misleading ISR-001 diag pointing at that next fn; (b) `#[isr(prio = -1)]` (negative integer) accepted; (c) `#[isr(prio = "high")]` (string instead of int) accepted; (d) `#[isr(prio)]` (bare ident, no value) accepted.
severity: misleading-diag (gap a) + silent-validation-gap (gaps b/c/d, RFC-0008 ISR substrate adopter-surface)
probe_file: probes/isr/isr_attr_validation_gaps.nr (probe-branch)
diagnostic_actual: gap a → ISR-001 fires on the wrong fn; gaps b/c/d → silent acceptance.
diagnostic_expected: (a) `error[ISR-004]: '#[isr]' may only be applied to fn items` at the attribute's own line; (b)/(c)/(d) `error[ISR-005]: 'prio' must be a non-negative integer literal` at the attribute site.
discovered_against: main v0.6.10 (probe rebased)
commit: probe (post-rebase) + main f93f5340
status: FULLY CLOSED — gap (a) closed in v0.6.31 via `enforce_isr_placement` (originally diag code ISR-004; renamed to ISR-008 in v0.6.32 because ISR-004 is reserved for "Vector name not recognized"). Gaps (b)/(c)/(d) closed in v0.6.32 via `validate_isr_prio` emitting ISR-007.
---

## Closure (main agent v0.6.31 + v0.6.32)

### Gap (a) — placement check (v0.6.31, code corrected in v0.6.32)

**Originally shipped as ISR-004 in v0.6.31.** Helper agent flagged
that ISR-004 is reserved in tools-suite (`code_title()` /
explanations / RFC-refs) for the planned "Vector name not
recognized for target" diag (RFC-0008 §3.1). v0.6.32 renamed the
placement-check diag to **ISR-008** and updated the fixture name
+ EXPECT header to match. ISR-004 is now back in its reserved
state for the future "Vector name not recognized" diag.

`compiler/nucleor_s1_compiler.nr` adds `enforce_isr_placement()`,
called at the top of `enforce_isr_contracts`. Scans source for
every `#[isr` occurrence, walks past the attribute body, then
walks forward looking for the next item-keyword (skipping
comments, whitespace, `pub` / `pub(...)`, and other attributes).
If the first item-keyword found is anything other than `fn`,
emits `error[ISR-008]` at the attribute's own source line so
the adopter can find and delete the misplaced attribute.

### Gap (b)/(c)/(d) — prio validation (v0.6.32)

`compiler/nucleor_s1_compiler.nr` adds `validate_isr_prio()`,
called per ISR entry inside `enforce_isr_contracts`. Scans the
attribute text for `prio` ident with proper boundary checks,
verifies the next non-ws token is `=` followed by a non-negative
integer literal, emits `error[ISR-007]` for any other shape:

- bare `#[isr(prio)]` — missing value
- `#[isr(prio = -N)]` — negative integer
- `#[isr(prio = "X")]` — string literal
- `#[isr(prio = ident)]` — non-digit value

## Adopter migration

```nucleor
// Pre-v0.6.31: silent on struct, ISR-001 on main (wrong fn):
#[isr]
struct S { x: i64 }
fn main() -> i32 { 0 }

// v0.6.31 + v0.6.32:
//   error[ISR-008]: `#[isr]` may only be applied to fn items;
//                   found `struct` after the attribute …
//   error[ISR-001]: … main (still leaks but cause is clear)

// Pre-v0.6.32: silent accept on all three malformed prio shapes.
// v0.6.32: ISR-007 fires at the attribute site for each:

#[isr(prio = -1)]      // → error[ISR-007]: prio must be NON-NEGATIVE
#[isr(prio = "high")]  // → error[ISR-007]: prio must be a non-negative integer literal, not a string
#[isr(prio)]           // → error[ISR-007]: prio is missing a value (use `prio = N`)

// Workaround: pass a non-negative integer literal:
#[isr(prio = 3)]       // OK
```

## Why two diags fire on placement (intentional)

ISR-001 still leaks to the next fn after a misplaced attribute.
`collect_isr_entries` is unchanged to keep the IR-emit path
stable across the ISR substrate. ISR-008 surfaces the real
cause; ISR-001 fires for the next fn that gets attached to the
misplaced attribute. A future ship can stop the leak by skipping
misplaced entries in `collect_isr_entries` directly.

## Promoted

- Fixtures:
  - `tests/err/err_isr_008_placement_on_struct.nr` (gap a, code
    renamed in v0.6.32).
  - `tests/err/err_isr_007_prio_negative.nr` (gap b).
  - `tests/err/err_isr_007_prio_string.nr` (gap c).
  - `tests/err/err_isr_007_prio_bare.nr` (gap d).
- Fix shipped: v0.6.31 (gap a) + v0.6.32 (gaps b/c/d + corrective
  rename of gap a's diag code).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
