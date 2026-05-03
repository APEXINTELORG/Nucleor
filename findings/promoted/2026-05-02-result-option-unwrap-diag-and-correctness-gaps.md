---
title: Three distinct gaps in Option/Result `unwrap` family — (1) `Option::unwrap()` on `None` panics with the internal-detail message `vec_get OOB: index 1, len 1` (later `index out of bounds: the len is 1 but the index is 1` after v0.6.30); (2) `Result::unwrap()` on `Err(x)` SILENTLY returns the err payload as if it were the ok payload (no panic, no diagnostic); (3) `Result::unwrap_err()` is not implemented (TYP-005 link fail).
severity: (2) silent-miscompute (CRITICAL — Err silently leaks through unwrap as if it were Ok); (1) misleading-diag (leaks internal Vec representation); (3) translation-fidelity gap
probe_file: probes/error_handling/unwrap_diag_and_correctness.nr (probe-branch)
diagnostic_actual: see "Repro" — three different shapes of broken behavior.
diagnostic_expected: (1) `PANIC: called Option::unwrap() on a None value`; (2) `PANIC: called Result::unwrap() on an Err value`; (3) `unwrap_err` either implemented or rejected at parse-time with a clear "method not yet supported" message.
discovered_against: main v0.6.17 (probe rebased)
commit: probe (post-rebase) + main fa2dfc90
status: FULLY CLOSED — gaps 1 + 2 closed in v0.6.33 via discriminant checks in `__nucleor_option_unwrap` / `__nucleor_result_unwrap`. Gap 3 closed in v0.6.34 via new `__nucleor_result_unwrap_err` helper + compiler dispatch + IR declare + tools-suite ABI sync.
---

## Closure (main agent v0.6.33) — gaps 1 + 2

`stdlib/runtime/nucleor_llvm_rt.c`:

- `__nucleor_option_unwrap` — checks `len < 2 || vec_get(opt, 0)
  != 0` (Some=tag-0). If true, panics with the canonical Rust
  message: `PANIC: called `Option::unwrap()` on a `None` value`.
- `__nucleor_result_unwrap` — checks `len < 2 || vec_get(res, 0)
  != 1` (Ok=tag-1, Err=tag-0). If true, panics with the
  canonical Rust message: `PANIC: called `Result::unwrap()` on
  an `Err` value`.

Both pass-through fast-paths preserved when the discriminant is
correct.

## Adopter migration

```nucleor
// Pre-fix Option::None.unwrap() — leaky diag:
let o: Option<i64> = None;
let v: i64 = o.unwrap();
// → PANIC: index out of bounds: the len is 1 but the index is 1 (LEAKY)

// v0.6.33:
// → PANIC: called `Option::unwrap()` on a `None` value (CANONICAL)

// Pre-fix Result::Err.unwrap() — SILENT MISCOMPUTE (CRITICAL):
let r: Result<i64, str> = Err("oops");
let v: i64 = r.unwrap();
// → silently returned the err payload's pointer as i64 — GARBAGE
//   data, program continued, no diagnostic. Adopters could not
//   tell that unwrap had "failed."

// v0.6.33:
// → PANIC: called `Result::unwrap()` on an `Err` value (FIXED)
```

## Why the silent leak was catastrophic

The pre-fix `__nucleor_result_unwrap` did `return vec_get(res, 1)`
unconditionally. For `Err(x)`, vec_get(res, 1) returned the err
payload — for `Err(str)`, the i64 representation of the str
pointer; for `Err(i64)`, the i64 itself; for `Err(struct)`, the
Vec handle as an i64. Whatever the adopter assigned to
`let v: i64 = r.unwrap();` was that garbage value. No diagnostic,
no panic, no exit. Programs continued and computed downstream
results from poison data.

This was the canonical "bug worse than a crash" pattern. Crashes
are detectable; silent miscompute is not.

## Forward-roadmap (gap 3)

`Result::unwrap_err()` is not implemented. Calls fail with TYP-005
("link fail / undefined function"). The method needs:
- A `__nucleor_result_unwrap_err` runtime helper (mirror of
  `__nucleor_result_unwrap` with inverted discriminant check).
- Compiler dispatch in `compiler/nucleor_s1_compiler.nr` at line
  ~20068 (the Result method dispatch site).
- A method-name registration in `unwrap_err`.

Small ship. Deferred to v0.6.34 or later.

## Promoted

- Fixtures (regression-lock):
  - `tests/fixtures/option_unwrap_none_panics.nr`
  - `tests/fixtures/result_unwrap_err_panics.nr`
- verify.sh steps wired:
  - `v0633_option_unwrap_none_panics`
  - `v0633_result_unwrap_err_panics`
- Fix shipped: v0.6.33 (gaps 1 + 2 only).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
