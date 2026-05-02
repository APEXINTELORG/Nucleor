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

- **STATUS: ALREADY CLOSED in v0.5.22 (stale finding).** Discovered against
  v0.5.17, fix shipped earlier as part of /loop work.
- Fix at `compiler/nucleor_s1_compiler.nr:25688-25689`: macro-form
  recognition table now routes `eprintln!` → mode 3 and `eprint!` →
  mode 4, mirroring the existing `println!`/`print!`/`format!` paths.
- Repro on v0.5.27 head:
  - `eprintln!("err-line")` → builds, runs, writes "err-line\n" to stderr
  - `eprint!("ok ")` → builds, writes "ok " to stderr
  - `eprintln!("formatted: {}", 42)` → builds, writes "formatted: 42\n"
- Pre-fix path was the unary-NOT fallthrough (`eprintln` ident + `!` +
  `(str)` → TYP-002). Now correctly handled before the unary-`!` parse.
- Promoted: 2026-05-01 by main agent. No new code change needed.
