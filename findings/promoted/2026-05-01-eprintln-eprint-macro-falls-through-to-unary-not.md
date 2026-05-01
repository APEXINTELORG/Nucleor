---
title: `eprintln!("...")` and `eprint!("...")` macro forms fall through to unary-NOT parse — adopter sees `error[TYP-002]: unary !` requires bool operand (got str)`
severity: silent-miscompute (macro recognition gap)
probe_file: probes/format/eprintln_macro_falls_through.nr (will be filed)
diagnostic_actual: `error[TYP-002]: unary !` requires a `bool` operand (got `str`)`. Pre-fix this silently lowered to xor-with-1 on the i64 representation.
diagnostic_expected: build success (matching `println!("...")` and `print!("...")` which DO recognize the macro form)
discovered_against: main v0.5.17 (probe 789cb62)
commit: probe 789cb62 + main 736d88a
---

## Repro

```nr
fn main() -> i32 {
    eprintln!("err-line");
    0
}
```

## Actual

```
error[TYP-002]: unary `!` requires a `bool` operand (got `str`). Pre-fix this silently lowered to xor-with-1 on the i64 representation. Use `x == 0` for logical negation of an integer, or cast to bool first (`(x != 0) == false`).
```

The parser sees `eprintln!("...")` as `eprintln` (identifier) then `!` (unary NOT) then `"..."` (str literal) — a unary-NOT applied to a str. TYP-002 correctly catches the unary-NOT-on-str hazard, but the actual user intent (a stderr-print macro) is invisible.

## Compare: `println!` / `print!` work

```nr
fn main() -> i32 {
    println!("hi {}", 42);   // works
    print!("hi {}", 42);     // works
    0
}
```

The format-macro expander recognizes `println` / `print` (modes 0/1) but not `eprintln` / `eprint` — they fall through to the unary-NOT parse path.

## Sister bare-fn forms

The bare-fn forms also have issues:

```nr
fn main() -> i32 {
    eprintln("err-line");   // ← TYP-005 "undefined function eprintln()"
    0
}
```

So:
- `eprintln("text")` → TYP-005 undefined fn (clang-link)
- `eprintln!("text")` → TYP-002 unary NOT

Neither works. Adopter writing canonical Rust stderr-print code has no surface that compiles cleanly.

## Hazard tier

Silent-miscompute / wrong-error. Adopter writes Rust:

```rust
eprintln!("error: invalid input");
```

Gets a confusing TYP-002 about unary NOT applied to str. The actual intent (stderr line) is invisible.

## Suspected fix

In `compiler/nucleor_s1_compiler.nr` format-macro expander
(referenced at v0.4.NNN ship, `fmt_build_expansion` entry):

1. Recognize `eprintln` and `eprint` as macro names (modes 3/4 alongside println/print modes 0/1).
2. Wire up `__nucleor_eprint_str` and `__nucleor_eprint_raw` runtime helpers (which exist since v0.4.135 per probe-side notes from a prior cycle).

This is the work I (probe agent) closed in probe-side Ship 33 era, but main agent never integrated the probe ship. Re-filing here so main can integrate.

## Memory-blow-up note

Not memory-related.

## Cross-ref

- v0.4.135 — `__nucleor_eprint_str` / `__nucleor_eprint_raw` runtime helpers landed
- Probe-side Ship 33 (`eprintln-eprint-macro-expansion`) — closed this on probe/exploration but never made it into main
- Heartbeat from v0.4.NNN era references this as already-filed-and-fixed; the fix only existed on the probe branch

## Probe

Filed alongside this finding.


## Promoted

- Fix shipped: v0.5.22 — `eprintln!(...)` and `eprint!(...)`
  macro forms now recognized by the format-macro expander,
  routed to `eprint(...)` (with newline) and `eprint_raw(...)`
  (no newline) runtime helpers.
- Compiler s1 + tools-suite mirror:
  - `fmt_build_expansion` mode dispatch extended: 3 = eprintln,
    4 = eprint. Empty-args branch handled.
  - `expand_format_macros_with_src` macro recognition: maps
    `eprintln` → mode 3, `eprint` → mode 4.
- Validation: `eprintln!("hello stderr"); eprint!("no newline");
  eprintln!("{}+{}={}", 1, 2, 3);` all build + run correctly,
  routing to stderr.
- Promoted: 2026-05-01 by main agent (probe commit 789cb62).
