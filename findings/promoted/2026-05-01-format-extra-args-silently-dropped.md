---
title: `format!("{}", 1, 2, 3)` (more args than placeholders) silently drops extras with no diagnostic — adopter loses arguments
severity: silent-miscompute
probe_file: probes/format/format_extra_args.nr (will be filed)
diagnostic_actual: builds clean, runtime prints just the first-substituted result; extras (2, 3) silently dropped
diagnostic_expected: compile-time warning or error — `error[FMT-NNN]: format string has 1 placeholder but 3 arguments supplied; arguments 2 and 3 are dropped silently. Either add `{}` placeholders for them or remove the extra args.`
discovered_against: main v0.5.10
commit: probe 930463c + main 701035f
---

## Repro

```nr
fn main() -> i32 {
    let s: str = format!("just {}", 1, 2, 3);
    print(s);   // prints "just 1" — args 2 and 3 silently dropped
    0
}
```

## Actual

Build succeeds with no diagnostic. Runtime output: `just 1`. Args `2` and `3` are dropped without any signal.

## Mirror direction is caught

The mirror case (more placeholders than args) IS caught:

```nr
let s: str = format!("a={} b={} c={}", 1, 2);   // 3 placeholders, 2 args
```

…either errors at compile or fails to print. The asymmetry is the
hazard: too few args is loud, too many args is silent.

## Hazard tier

Silent-miscompute. Adopter typo'd a placeholder removal but left the arg, OR refactored the format string and forgot to drop a now-unused arg. The arg sits there unused with no signal, possibly with side effects (`format!("hi {}", 1, expensive_call())` — `expensive_call()` evaluates and is silently discarded).

## Suspected fix

Mirror the existing too-few-args check. In the format-string parser:

1. Count `{}` (and named `{name}`) placeholders.
2. Count fmt args (the `, args...` after the format string).
3. If args > placeholders → emit FMT-NNN diagnostic naming the dropped arg positions.

Should be ~5-10 lines next to the existing too-few-args check.

## Cross-ref

- The probe heartbeat references "fmt-extra-args-symmetric-halt" as a closed Ship N era ship on probe/exploration. That ship was NEVER integrated into main — main has my finding docs but didn't merge probe code. This is a re-file for main agent's tracking.
- v0.4.70 — caught placeholder>args (the loud direction)
- The recent v0.4.NNN (~v0.4.139 era) format helpers — similar parse-time validation can extend here

## Memory-blow-up note

Not memory-related.

## Probe

Filed alongside this finding.


## Promoted

- Fixture: `tests/err/err_fmt_003_extra_args.nr` —
  `format!("just {}", 1, 2, 3)` halts with FMT-003 naming the
  1-vs-3 placeholder/arg mismatch + 2 dropped args.
- Fix shipped: v0.5.11 — pure compile-time check, no runtime
  changes. Mirrors v0.4.70's placeholder>args check direction.
  - `compiler/nucleor_s1_compiler.nr` `fmt_build_expansion`:
    after the placeholder loop, when `arg_idx < n_args` halt
    with FMT-003 naming counts + format body.
  - `compiler/nucleor_tools_suite.nr` `fmt_build_expansion`:
    mirrored (drift gate enforces).
  - `is_compile_time_error` (s1): adds `FMT-003`.
  - Tools-suite explain registry: title + cause + hint entries
    for FMT-003.
  - `tools/verify.{sh,ps1}`: adds `FMT-003` to the
    cli_explain_full_smoke codes lists.
- Verify gate: existing per-err loop picks up the new fixture.
  693/693 PASS env-off + env-on (was 692; one new err fixture).
- IR fixed-point: round-1 == round-2 holds (no new runtime
  declares; pure compile-time check addition).
- Promoted: 2026-05-01 by main agent (from probe-agent prep on
  origin/probe/exploration commit e6d47b0).
