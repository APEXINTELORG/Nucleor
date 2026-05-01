---
title: MATCH-012 emits clean diagnostic via `print` then immediately `panic()` — adopter sees both the proper error AND a "PANIC" line
severity: cosmetic / wrong-error display
probe_file: probes/match/match_struct_destructure.nr (existing)
diagnostic_actual: clean error[MATCH-012] text + raw "PANIC: nucleor: MATCH-012 ..." line on next line
diagnostic_expected: just the clean error[MATCH-012] text + clean exit 1 (no PANIC stutter)
discovered_against: probe/exploration tip after ship 42 (commit dd48f0f)
commit: dd48f0f
---

## Repro

```nr
struct P { x: i32, y: i32 }

fn classify(p: P) -> i32 {
    match p {
        P { x: 0, y: 0 } => 0,
        P { x, y } => x + y,
    }
}

fn main() -> i32 {
    print_int(classify(P { x: 0, y: 0 }));
    0
}
```

## Actual

```
error[MATCH-012]: struct pattern field after `:` must be an identifier (rename-binding form, e.g. `Point { x: rename }`). Field-equality literal patterns like `Point { x: 0, y: 0 }` are not yet supported — match the field with a binding (`Point { x, y }`) and use a guard `if x == 0 && y == 0 => ...` instead.
PANIC: nucleor: MATCH-012 non-identifier in struct pattern field
```

The diagnostic text is correct + actionable. But the `panic()` on
the next line emits a raw "PANIC: nucleor: ..." string that
duplicates the error code and doesn't match the canonical Nucleor
diagnostic format.

## Root cause

`compiler/nucleor_s1_compiler.nr:963-965`:

```nr
if pk(tokens, cp) != 1 {
    print("error[MATCH-012]: ...");
    panic("nucleor: MATCH-012 non-identifier in struct pattern field");
};
```

The `print` followed by `panic` is the parse-time pattern (parse
errors don't have `diags` vec available — diag_add_ex requires it).
But the `panic()` call:
1. Adds a duplicate error message via the runtime panic handler
2. Marks the rc as "panic" rather than "compile-error"
3. Reads as a compiler bug to adopters who don't know it's a deliberate halt

## Expected

Either:

**A — use a parse-error diag-emit mechanism.** Other parse-time
diagnostics (e.g. NR020 in `expect_tok`) emit through a parse-time
diag mechanism that doesn't panic. Refactor MATCH-012 onto that
path.

**B — replace `panic()` with `exit(1)` after print.** Cleaner halt
without the duplicate "PANIC" line. Matches the parse-time err handle convention used elsewhere.

**C — keep panic but suppress the second message.** Smallest patch:

```nr
if pk(tokens, cp) != 1 {
    print("error[MATCH-012]: ...");
    panic("");   // empty message — runtime won't print second line
};
```

…assuming the panic runtime suppresses empty messages. Otherwise:

```nr
print("error[MATCH-012]: ...");
exit(1);
```

If `exit` isn't available at parse time, refactor to use a parse-
error sentinel.

## Severity

Cosmetic / wrong-error display. The CORRECT diagnostic is emitted —
adopter sees the actionable text. The duplicate PANIC line is
noise. Lowest priority of the 2026-04-30 sweep.

## Sister sites

Same `print + panic` parse-error pattern at:

- Line 1959: `let (a, b) = ...` tuple-destructure unsupported (panics with `nucleor: tuple destructuring in 'let' not supported`)
- Possibly other parse-time recovery paths

A unified parse-error emit helper would close all of them.

## Cross-ref

- v0.4.163 — added MATCH-012 itself; the panic-after-print shape was
  introduced in this ship.

## Probe

`probes/match/match_struct_destructure.nr` (existing, runs the
canonical repro).

## 2026-04-30 (post-ship-43) — attempted ship + reverted

Tried changing the panic message from `nucleor: MATCH-012
non-identifier in struct pattern field` to `compile aborted (see
error[MATCH-012] above)`. Same change at the tuple-destructure
sister site (line 1959).

Reverted: 5 sibling verify gate steps (`T3.83` for tuple
destructure, `T3.84` trait assoc const, `T3.85` impl assoc const,
plus 2-3 more) explicitly grep `PANIC: nucleor: <description>` text
in their negative-test contracts. Changing the format breaks the
contract across all sister sites at once — that's a refactor not a
probe ship.

**Properly closing this finding requires:**
1. Pick a canonical halt-message format (e.g. `compile aborted (see
   error[CODE] above)`).
2. Update ALL parse-time print+panic sites (estimate 5-7 sites
   across MATCH-012, tuple destructure, trait assoc const, impl
   assoc const, NR020, parse_primary fallthrough, etc.) in one
   batch.
3. Update each sibling verify gate step's grep expectation.
4. Single ship — main-agent territory because it touches verify.sh
   contracts.

Filing back at finding-only status; deferred for main-agent batch refactor.


## Promoted

- Fixture: `tests/err/err_match_012_struct_pattern_literal.nr`
- Verify gate step: `t_match_012_single_line` — asserts MATCH-012 appears EXACTLY ONCE in build output (was 2x pre-fix).
- Fix shipped: v0.4.276 — folded the dual `print() + panic()` at compiler/nucleor_s1_compiler.nr:972 into a single panic() carrying the full diag text. Matches the MATCH-013 pattern (line ~1040). Eliminates the duplicate-text stutter.
- Caveat: the leading "PANIC: " prefix from `__nucleor_panic` runtime helper still appears. Removing it requires adding a `diag_halt` runtime helper that exits without the prefix — deferred follow-up. The probe-finding-expected output ("just the clean error[MATCH-012] text + clean exit 1") needs that helper. Current ship is a real improvement (no stutter) without runtime changes.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on origin/probe/exploration commit dd48f0f vintage)
