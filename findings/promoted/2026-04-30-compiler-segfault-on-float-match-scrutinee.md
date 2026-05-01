---
title: COMPILER SIGSEGV on `match <f64> { <float-literal> => ... }`
severity: compiler-meltdown
probe_file: probes/arith/float_as_match_scrutinee.nr
diagnostic_actual: compiler exits with ACCESS_VIOLATION (Windows exit code -1073741819 = 0xC0000005), no diagnostic, no output
diagnostic_expected: clean compile and runtime print, OR a clean MATCH-NNN diagnostic if float scrutinees are intentionally unsupported
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
status: CLOSED in v0.4.206 — two-site fix. (1) parse_match_one_pattern at line 933 rejects float-lit pattern tokens (70, 124, 125) at parse time with MATCH-013 panic. (2) type-check at kind 38 (line 12642) rejects float-typed scrutinees so wildcard-only matches on a float also halt clean. Compiler-meltdown class fully eliminated. Regression-guard fixture at tests/fixtures/repro_v206_match_float_scrutinee_halts.nr.
---

## Repro

```nr
fn main() -> i32 {
    let x: f64 = 1.5;
    let r: i32 = match x {
        1.5 => 100,
        _ => 0,
    };
    print_int(r);
    0
}
```

## Actual

```
$ ./bin/nucleor.exe build probes/arith/float_as_match_scrutinee.nr -o float_as_match_scrutinee
  source: probes/arith/float_as_match_scrutinee.nr (137 bytes)
  mode: fast (ownership + type)
  [compiler exits — no further output, no diagnostic]
exit code: -1073741819 (0xC0000005, ACCESS_VIOLATION)
```

The compiler **crashes with SIGSEGV / Windows access violation** while
processing the source. No diagnostic is emitted. No `.ll` file is
produced. The user gets an opaque non-zero exit and a missing artifact.

## Resource use at crash

- wall: 0.25s
- peak RSS: 4 MB
- Run-Capped did NOT fire — this is not an OOM or timeout, it's a
  null/bad-pointer dereference inside the compiler's source.

## Expected

Either:
- **Clean compile + run**: `r` should be `100` (1.5 == 1.5), program
  prints `100`. (Note: float equality matching is fragile generally,
  but if the language permits it then this should work for exact
  literal equality.)
- **Clean diagnostic**: a MATCH-NNN saying float scrutinees are not
  supported (Rust forbids float patterns since 1.0; Nucleor may have
  the same intentional rejection that this code path forgot to wire).

## Severity

compiler-meltdown. Per mandate this is the highest severity tier and
jumps to the top of the priority queue regardless of cheapest-fix.
SIGSEGV inside the compiler with no diagnostic is the worst possible
adopter experience: they don't even know what shape of construct is
unsupported.

## Suspected location

The match-scrutinee type-check or pattern-match codegen lowering. Two
likely failure points:

1. The pattern-arm comparison codegen tries to emit an integer-equality
   compare (`icmp eq`) on the scrutinee + literal, but the scrutinee is
   `f64`. Casting / switching emit-paths between integer and float
   compares may be missing the float branch and following a NULL
   pointer through a switch table.

2. The match-arm exhaustiveness analyzer attempts to enumerate the
   value range for an unbounded numeric scrutinee. For `i32` /
   `i64` it has range-pattern logic; for `f64` it may dereference an
   uninitialized range descriptor.

Recommendation: gate the match-scrutinee type at the kind-38 dispatch
site to reject `f64` / `f32` with a clean MATCH-NNN BEFORE reaching
either codegen path. Mirrors the v0.4.140 (MATCH-011: heterogeneous
match arms — runtime SIGSEGV close) playbook: detect at type-check
rather than relying on codegen sanity.

## Cross-ref

- v0.4.140 (MATCH-011: heterogeneous match arms — runtime SIGSEGV
  close). Same SIGSEGV-on-match-pattern hazard family.
- v0.4.143 (NUM-023: float / bool SIGSEGV). Same float-handling
  SIGSEGV hazard family.

This finding is a **compiler-side** SIGSEGV in the same family — the
compiler does to itself what those two prior runtime bugs did to user
programs.

## Reproducibility

Reproduces every run on commit 213fee9, no env vars needed. Fast
(<0.3s wall). No memory growth — clean SIGSEGV.

## Memory-blow-up note

This is NOT a memory blow-up — RSS stays at 4 MB. It's a null/bad-pointer
read. The 1024 MB e-stop wouldn't catch this class of meltdown. A
SIGSEGV-handler in the compiler that emits a "compiler internal error"
diagnostic before exiting would catch it cleanly, but that's a larger
piece of work than the targeted fix above.


## Promoted

- Status frontmatter: see top of file. Closure version: **v0.4.206**.
- Regression-guard fixture: `tests/fixtures/repro_v206_match_float_scrutinee_halts.nr`.
- Verify gate: existing per-feature loop picks up the fixture above.
- Promoted: 2026-04-30 by main agent (footer backfilled 2026-05-01 per probe-agent Q3 footer-shape uniformity request).
