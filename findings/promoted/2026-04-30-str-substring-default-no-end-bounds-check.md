---
title: `str_substring(s, lo, hi)` does not bounds-check the `hi` argument — out-of-range `hi` returns a truncated/garbage slice silently. Adopters writing canonical Rust slicing (which panics on OOB) get silent wrong output.
severity: silent-miscompute (silent OOB on default helper) — discoverability gap (strict variant existed since v0.3.220 but wasn't surfaced)
probe_file: probes/str/substring_oob.nr (probe-branch)
diagnostic_actual: pre-discoverability fix — adopters didn't know `str_substring_strict` existed; default `str_substring` returned silently-truncated output on OOB.
diagnostic_expected: either (a) flip the default to bounds-checked (breaking change), OR (b) discoverability — surface `str_substring_strict` prominently in language-tour + add migration doc + opt-in fixture.
discovered_against: main v0.4.x (probe rebased)
commit: probe (post-rebase) + main 3853a48
status: ADDRESSED in v0.6.15 via discoverability route (parallel-1 lane D, integrated `b531e9f`). Behavior FLIP (make strict the default) deferred to a future breaking-change ship.
---

## Why discoverability instead of behavior FLIP

`str_substring_strict` already existed (since v0.3.220) — the strict
out-of-bounds-rejecting variant of `str_substring`. The probe finding
asked for a behavior FLIP (make strict the default), but main agent's
analysis was that's a breaking-change-class flip and the right v0.6
move is **discoverability**: surface the strict helper prominently so
adopters choosing strict semantics aren't hunting for it.

## Repro (no behavior change in v0.6.15 — see workaround)

```nr
let s: str = "Hello";
let bad: str = str_substring(s, 0, 100);  // returns "Hello\0" silently
```

Workaround that ships in v0.6.15 with explicit migration doc:

```nr
let s: str = "Hello";
let strict: str = str_substring_strict(s, 0, 100);  // panics OOB
```

## Closure (parallel-1 lane D v0.6.15)

Pure docs + fixture ship — no compiler / runtime change.

- `docs/migrations/str_substring_strict.md` — new migration guide
  documenting when to use which helper, with adopter copy-paste
  recipes.
- `docs/language-tour.md` — Strings section now points at the
  migration doc explicitly: "Use `str_substring_strict` when the
  caller cannot already prove substring bounds."
- `tests/features/str_substring_strict_basic.nr` — new positive
  fixture asserting in-bounds strict substring works the same as
  the fast helper.
- `tools/verify.sh` — new step `t_str_substring_strict_basic` runs
  the new fixture every gate.

Spike doc: `docs/milestones/spikes/track_str_substring_strict_migration_2026-05-02.md`.

## Forward-roadmap (behavior FLIP)

Making `str_substring_strict` the default is a breaking-change-class
flip — every adopter using `str_substring(s, lo, hi)` with potentially
out-of-range bounds (perhaps deliberately to clip to length) would
suddenly hit a panic. Deferred to a future ship that bundles a
broader breaking-change cycle (probably v0.8 stabilization).

## Promoted

- Fixture: `tests/features/str_substring_strict_basic.nr` (positive).
- Migration doc: `docs/migrations/str_substring_strict.md`.
- Fix shipped (discoverability): v0.6.15 (`1224b2f`).
- Behavior FLIP: deferred (forward-roadmap).
- Promoted: 2026-05-02 PM by main agent (probe commit `c4a76e2` on
  `origin/probe/exploration`).
