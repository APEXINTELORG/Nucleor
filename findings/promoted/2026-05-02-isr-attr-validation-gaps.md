---
title: `#[isr]` attribute validation has three gaps — (a) when placed on a non-fn item (e.g. `struct`), the attribute silently no-ops on the struct AND leaks to the next fn, producing a misleading ISR-001 diag pointing at that next fn; (b) `#[isr(prio = -1)]` (negative integer) accepted; (c) `#[isr(prio = "high")]` (string instead of int) accepted; (d) `#[isr(prio)]` (bare ident, no value) accepted.
severity: misleading-diag (gap a) + silent-validation-gap (gaps b/c/d, RFC-0008 ISR substrate adopter-surface)
probe_file: probes/isr/isr_attr_validation_gaps.nr (probe-branch)
diagnostic_actual: gap a → ISR-001 fires on the wrong fn; gaps b/c/d → silent acceptance.
diagnostic_expected: (a) `error[ISR-004]: '#[isr]' may only be applied to fn items` at the attribute's own line; (b)/(c)/(d) `error[ISR-005]: 'prio' must be a non-negative integer literal` at the attribute site.
discovered_against: main v0.6.10 (probe rebased)
commit: probe (post-rebase) + main f93f5340
status: PARTIALLY CLOSED — gap (a) closed in v0.6.31 via `enforce_isr_placement`. Gaps (b)/(c)/(d) deferred to a separate ship.
---

## Closure (main agent v0.6.31) — gap (a) only

`compiler/nucleor_s1_compiler.nr` adds `enforce_isr_placement()`,
called at the top of `enforce_isr_contracts`. Scans source for
every `#[isr` occurrence, walks past the attribute body, then
walks forward looking for the next item-keyword (skipping
comments, whitespace, `pub` / `pub(...)`, and other attributes).
If the first item-keyword found is anything other than `fn`,
emits `error[ISR-004]` at the attribute's own source line so
the adopter can find and delete the misplaced attribute.

## Adopter migration

```nucleor
// Pre-v0.6.31: silent on struct, ISR-001 on main (wrong fn):
#[isr]
struct S { x: i64 }
fn main() -> i32 { 0 }

// v0.6.31:
//   error[ISR-004]: `#[isr]` may only be applied to fn items;
//                   found `struct` after the attribute …
//   error[ISR-001]: … main (still leaks but cause is clear)
//
// Workaround: remove `#[isr]` from the struct (it has no effect
// on a non-fn item) or move it to the actual handler fn.
```

## Why two diags fire (intentional)

ISR-001 still leaks to the next fn in this ship. `collect_isr_entries`
is unchanged to keep the IR-emit path stable across the ISR
substrate. ISR-004 surfaces the real cause; ISR-001 fires for
the next fn that gets attached to the misplaced attribute. A
future ship can stop the leak by skipping misplaced entries in
`collect_isr_entries` directly.

## Forward-roadmap

Not closed in this ship:

- **Gap (b)** — `#[isr(prio = -1)]` accepted. Negative priority has
  no defined meaning on common interrupt controllers (NVIC: 0–255
  unsigned; PLIC: 1–7 unsigned).
- **Gap (c)** — `#[isr(prio = "high")]` accepted. Documentation
  lists prio as integer; string is silently ignored.
- **Gap (d)** — `#[isr(prio)]` (bare ident, no value) accepted.
  Should be either a syntax error or an explicit "missing value"
  diag.

All three are validation gaps in the prio attribute parser. A
follow-up ship can add `validate_isr_prio()` to `enforce_isr_
contracts` that scans `attr_text` for `prio = X` and emits
`ISR-005` for malformed X (negative-int / string / missing
value).

## Promoted

- Fixture: `tests/err/err_isr_004_placement_on_struct.nr`.
- Fix shipped: v0.6.31 (gap a only).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
