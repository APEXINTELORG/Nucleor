---
title: `match x { -10..=-1 => ... }` and `match x { 0..=-1 => ... }` — match range patterns with negative literal bounds parse-failed because the leading `-` was treated as a unary-minus operator followed by a literal instead of being recognised as part of the range bound.
severity: parse-failure / wrong-error (canonical Rust shape rejected without workaround pointer)
probe_file: probes/match/range_negative_bound.nr (probe-branch)
diagnostic_actual: pre-fix — generic parser error at the `-` token; no workaround pointer.
diagnostic_expected: clean halt with `error[MATCH-014]: negative literal bounds in range patterns are not supported yet` + workaround pointer (use guard or shift domain).
discovered_against: main v0.5.x (probe rebased)
commit: probe (post-rebase) + main cc8311f
status: CLOSED in v0.6.14 (parallel-1 lane C, integrated `7a60b9d`).
---

## Repro

```nr
fn main() -> i32 {
    match -5 {
        -10..=-1 => 1,    // ← MATCH-014 in v0.6.14
        _        => 0,
    };
    0
}
```

Pre-fix: generic NR0xx parse error at the `-` token, no workaround
pointer.
Post-fix: clean `error[MATCH-014]` halt with the workaround pointer
(use a guard, or shift the domain to non-negative bounds).

## Closure (parallel-1 lane C v0.6.14)

`compiler/nucleor_s1_compiler.nr` — match range pattern parser now
detects the `-literal..=` and `..=-literal` shapes at parse time and
emits MATCH-014 instead of falling through to a generic parse error.
Spike doc:
`docs/milestones/spikes/track_match_range_negative_bound_2026-05-02.md`.

Two negative fixtures lock the diagnostic:
- `tests/err/err_match_range_negative_lower_bound.nr`
- `tests/err/err_match_range_negative_upper_bound.nr`

`docs/spec/Nucleor_Error_Codes.md` updated with MATCH-014 entry +
`nuc explain MATCH-014` text. Verify gate step
`v0.6 MATCH-014 negative range-pattern bounds diagnostic` (line ~4959
in `tools/verify.sh`) runs both fixtures every gate.

## Forward-roadmap (full negative-literal support)

Full negative-literal range patterns require a parser change to
recognise `-N` as a single literal token in pattern context (rather
than as a unary expression). Deferred to a follow-on RFC; for now
adopters get a loud halt + workaround.

## Promoted

- Fixture: 2 negative fixtures locked above.
- Fix shipped: v0.6.14 (`3853a48`).
- Promoted: 2026-05-02 PM by main agent (probe commit `c4a76e2` on
  `origin/probe/exploration`).
