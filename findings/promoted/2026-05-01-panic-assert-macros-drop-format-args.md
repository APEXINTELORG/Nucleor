---
title: `panic!`, `assert!`, `assert_eq!`, `assert_ne!` macros silently DROP all format args after the format string. `panic!("got {}", x)` produces `PANIC: got {}` (no expansion). Custom messages on `assert!` are completely lost.
severity: silent-miscompute (diagnostic-quality, debugging UX, security-adjacent for production panics)
probe_file: probes/asserts/macro_format_args_drop.nr (probe-branch)
diagnostic_actual: pre-fix — format placeholders `{}`, `{:?}`, `{:.2}` etc. left as literal text in the panic message; subsequent args dropped; no warning.
diagnostic_expected: same expansion as `println!` — `panic!("got {}", x)` → `PANIC: got 7` for x=7.
discovered_against: main v0.5.28 (probe rebased)
commit: probe (post-rebase) + main 010dba8f
status: FULLY CLOSED — `panic!` closed in v0.6.39 via mode-5 in `fmt_build_expansion`. `assert!`/`assert_eq!`/`assert_ne!` CLOSED in v0.6.76 via textual rewrite at `expand_format_macros` (cheap name gate + comma-count + `"`-shape check; rewrite to `if !(cond) { panic!(fmt, args); };` reusing mode-5 fmt_build_expansion).
---

## Closure (main agent v0.6.39) — `panic!` only

`compiler/nucleor_s1_compiler.nr` `expand_format_macros` macro-
detector — adds mode 5 for `panic!`, routes through the same
`fmt_build_expansion` path as `println!`/`print!`/`format!`/
`eprintln!`/`eprint!`. Mode 5 produces `panic(<formatted_chain>)`
— format args expanded into a single str before reaching the
runtime helper. `panic!` removed from the legacy strip-`!`
fallback list (now exclusively mode 5).

## Adopter migration

```nucleor
fn validate(input: i64) -> i64 {
    if input < 0 {
        panic!("validate: expected non-negative, got {}", input);
    }
    input
}

// Pre-v0.6.39: PANIC: validate: expected non-negative, got {}
// v0.6.39:     PANIC: validate: expected non-negative, got -3
```

All format-spec features supported by `println!` (`{:.2}`,
`{:?}`, `{:#x}`, `{:>10}`, etc.) flow through unchanged.

## Forward-roadmap (gaps 2+)

Not closed in this ship:

- `assert!(cond, fmt, args...)` custom-message format args.
- `assert_eq!(a, b, fmt, args...)` and `assert_ne!` custom-
  message format args.
- `assert_eq!`/`assert_ne!` ptr-cmp on str (sister finding
  `2026-05-01-assert-eq-ne-macros-silent-miscompute-on-str` —
  closed v0.6.20).

The `assert*!` family takes a condition first and the format
args after, which needs a different expansion shape than
`panic!`. Deferred.

## Promoted

- Smoke validation: `panic!("got: {}", 42)` outputs `PANIC: got: 42`.
- Fix shipped: v0.6.39 (panic! only).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
