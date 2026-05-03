---
title: `str_to_int(bogus)` and `str_to_f64(bogus)` silently return 0 / 0.0 with no diagnostic. Bogus input is indistinguishable from a valid "0" / "0.0" input. Adopters validating user input via these helpers have a security-adjacent hazard.
severity: silent-miscompute (security-adjacent — user-input validation)
probe_file: probes/strings/str_to_int_bogus.nr (probe-branch)
diagnostic_actual: pre-fix — build + run succeed; bogus input returns the type's zero value.
diagnostic_expected: PANIC, Option-returning variant, or Result-returning variant.
discovered_against: main v0.5.28 (probe rebased)
commit: probe (post-rebase) + main a08040bd
status: ALREADY ADDRESSED — v0.5.12 shipped `str_to_int_strict` (panics on parse failure with a clean diagnostic). Adopters validating user input call the strict variant; the lenient `str_to_int` is intentionally fallback-to-0 for adopter ergonomics in math-heavy code.
---

## Closure (existing v0.5.12 ship)

The strict variant `str_to_int_strict` was added in v0.5.12 (closes
probe finding `2026-05-01-str-to-int-silent-zero-on-invalid`).
Verify gate has a regression-lock fixture
`tests/fixtures/v0512_str_to_int_strict_panics.nr` and a verify
step `v0512_str_to_int_strict_panic` that asserts the strict
variant panics on bogus input with the canonical message.

The probe finding here is asking for the SAME behavior — but for
the lenient default. Changing the lenient default would break
every adopter using `str_to_int` as a fallback-to-0 in math /
parsing pipelines (which is the documented v0.4.x design).

## Adopter migration

For input-validation contexts where parse failure is a hard
error:

```nucleor
// Pre-v0.5.12 (and current default behavior):
let n: i64 = str_to_int(user_input);   // bogus → 0 silently
if n >= 0 && n <= 150 { … };           // "abc" passes, etc.

// v0.5.12 strict variant (existing):
let n: i64 = str_to_int_strict(user_input);
//          ^ PANICs on bogus input with clean message
//            'str_to_int_strict: cannot parse "abc" as integer'
```

For float parsing, no `str_to_f64_strict` exists yet — that's a
forward-roadmap symmetric ship (would mirror v0.5.12's pattern
exactly). Track for a follow-up.

## Forward-roadmap

- `str_to_f64_strict(s) -> f64` — symmetric to `str_to_int_strict`.
- `str_to_int_opt(s) -> Option<i64>` and
  `str_to_f64_opt(s) -> Option<f64>` — Rust-style fallible
  variants. Not yet shipped because Option-returning runtime
  helpers require Vec-shaped return value (Option<T> is
  internally `Vec[discriminant, payload]`), which is non-trivial
  for the C-side helpers — needs a Vec-construct API in the
  runtime helpers' return path.

## Promoted

- Existing fixture: `tests/fixtures/v0512_str_to_int_strict_panics.nr`.
- No new code shipped — workaround documented; forward-roadmap
  noted.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
