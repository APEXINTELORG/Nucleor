---
title: `str_to_int(<invalid>)` returns 0 silently — adopter can't distinguish parse-failed-to-zero from parse-succeeded-to-zero
severity: silent-miscompute (parsing-error class)
probe_file: probes/numeric/str_to_int_silent_zero.nr (will be filed)
diagnostic_actual: silent — `str_to_int("not a number")` and `str_to_int("0")` both return 0 with no signal
diagnostic_expected: either (a) panic on invalid input (matching Rust `i64::from_str_radix(...).unwrap()`), OR (b) return Result<i64, _> requiring the adopter to handle parse failures, OR (c) ship a `str_to_int_strict()` that panics on invalid input (mirroring v0.5.10's panic-on-iN-MIN/-1 pattern + Ship 41's str_substring strict-by-default convention)
discovered_against: main v0.5.10
commit: probe 930463c + main 701035f
---

## Repro

```nr
fn main() -> i32 {
    let a: i64 = str_to_int("not a number");
    print_int(a as i32);   // prints 0

    let b: i64 = str_to_int("");
    print_int(b as i32);   // prints 0

    let c: i64 = str_to_int("123abc");
    print_int(c as i32);   // prints 123 (drops "abc" silently)

    let d: i64 = str_to_int("0");
    print_int(d as i32);   // prints 0 — INDISTINGUISHABLE from a/b above

    0
}
```

## Three failure shapes

| Input | Returns | Adopter expects | Hazard |
|---|---|---|---|
| `"not a number"` | `0` | parse failure signal | silently 0 — adopter treats as valid 0 |
| `""` | `0` | parse failure signal (or panic on empty) | silently 0 |
| `"123abc"` | `123` | strict parse (full string consumed) OR Result with remainder | silently parses prefix, drops `abc` |
| `"0"` | `0` | the value 0 | correct, but indistinguishable from above failures |

## Hazard tier

**Silent-miscompute (parsing class)**. Sister to:
- v0.4.108 / TYP-021 family (void coerced to 0)
- Ship 42 era vec_pop void-coerce-to-zero
- The general "0-is-the-default-on-failure" anti-pattern Nucleor has been closing

Adopters porting from Rust write:

```nr
fn parse_user_input(s: str) -> i64 {
    str_to_int(s)
}

fn validate(input: str) -> bool {
    if str_to_int(input) > 0 { return true; };   // misses "not a number" → 0 → false (good?)
    if str_to_int(input) == 0 { ... }              // CANNOT distinguish "0" from "garbage"
    return false;
}
```

The "0 == failure" convention bites in any code path that legitimately needs to handle 0 as a valid value AND distinguish parse-failed from parse-succeeded.

## Suspected fix

Three options matching Nucleor's existing patterns:

**A — split helpers (Ship 41 / str_substring template)**:
- `str_to_int(s)` → strict-by-default: panic on invalid input
- `str_to_int_unchecked(s)` → opt-in current behavior (returns 0 on invalid)
- Mirrors the Ship 39+40+41 migration pattern. Adopters get the safe default; perf-conscious paths (lexer/parser internal) opt into _unchecked.

**B — Result return**:
- `str_to_int(s) -> Result<i64, ParseIntError>` (or `Option<i64>`)
- Match-arm forces explicit handling

**C — runtime panic with adopter override env var**:
- Default: panic on invalid (matching v0.5.10's narrow-arith family)
- `NUCLEOR_STR_TO_INT_LENIENT=1` to suppress (matching `NUCLEOR_VEC_OOB_LENIENT` pattern)

Recommended: **A** (split helpers). Already-filed sister finding `2026-04-30-str-char-at-oob-silent-read.md` recommends the same pattern; both could be done together as a single bounds-check-strictness ship.

## Cross-ref

- v0.5.10 — narrow-arith MIN/-1 panics cleanly. Same family discipline should apply to parsing helpers.
- Ship 41 (str_substring strict-by-default) — successful precedent for the split-helper migration template.
- 2026-04-30-str-char-at-oob-silent-read.md (sister finding for the str_char_at OOB case)
- str_to_int has 686 self-host callsites (similar scale to str_substring); migration template applies.

## Memory-blow-up note

Not memory-related directly. Silent-miscompute on adopter-facing parsing.

## Probe

Filed alongside this finding.


## Promoted

- Fixtures:
  - `tests/features/str_to_int_strict.nr` — positive coverage:
    valid inputs (123, 0, -42, "  17  " with leading/trailing
    whitespace) round-trip cleanly. Exit 0.
  - `tests/fixtures/v0512_str_to_int_strict_panics.nr` —
    runtime-panic fixture: `str_to_int_strict("not a number")`
    panics with rc=1 and "PANIC: str_to_int_strict:" prefix.
- Fix shipped: v0.5.12 — Option A from the finding (split-helper
  template). Mirrors v0.4.279 `str_char_at_strict` opt-in.
  - **Runtime** (`stdlib/runtime/nucleor_llvm_rt.c`):
    `__nucleor_str_to_int_strict(const char *s)` panics on:
    NULL input, empty string, no parseable integer, trailing
    non-whitespace garbage, i64 range overflow. Trailing
    whitespace tolerated (mirrors `strtoll`'s leading-whitespace
    behavior).
  - **Compiler** (s1 + tools-suite mirror): name resolver, sig
    str-arg-0 list, IR `declare` line.
- Verify gate: new step `v0512_str_to_int_strict_panic` asserts
  the runtime-panic shape (rc != 0, stderr contains
  "PANIC: str_to_int_strict:"). Existing per-feature loop picks
  up the positive fixture.
- Lenient default unchanged — perf-conscious paths
  (lexer/parser internal, hot loops) keep silent-0 on invalid;
  adopters opt into strict by switching the helper name.
- Sister Options B (Result return) and C (compile-time
  validation) are NOT taken — Option B is a breaking ABI change
  for every existing caller; Option C only catches literal
  inputs and misses the dynamic-input case the finding
  highlights. Option A delivers what adopters actually need
  (a clean strict variant) without breaking the existing
  surface.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on
  origin/probe/exploration commit 930463c).
