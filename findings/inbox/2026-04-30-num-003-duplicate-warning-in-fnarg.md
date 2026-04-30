---
title: NUM-003 emits twice for one `as` cast when the cast is in fn-call argument position
severity: wrong-error
probe_file: probes/casts/duplicate_num_003_fnarg.nr
diagnostic_actual: two identical NUM-003 warnings (same span) for one cast
diagnostic_expected: one NUM-003 warning per cast site
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
---

## Repro

```nr
fn main() -> i32 {
    let x: i64 = 100;
    print_int(x as i32);
    0
}
```

## Actual

```
$ ./bin/nucleor.exe build probes/casts/duplicate_num_003_fnarg.nr -o p
  source: probes/casts/duplicate_num_003_fnarg.nr (...)
  mode: fast (ownership + type)
warning[NUM-003]: `as` cast loses precision: i64 (64-bit) -> i32 (32-bit)
  --> fn main@line 1:4
warning[NUM-003]: `as` cast loses precision: i64 (64-bit) -> i32 (32-bit)
  --> fn main@line 1:4
  ...
  compiled: target\p.exe
```

Two identical NUM-003 warnings for one cast site, both pointing at the
same span (`fn main@line 1:4`).

## Expected

One NUM-003 per cast site.

## Hypothesis

The cast is in fn-call argument position, so the cast expression appears
to be type-checked twice:

1. once when typing the argument expression
2. again when coercing the argument to `print_int`'s parameter type

Both passes hit the NUM-003 emit path. Counter-evidence: a let-bound
variant where the cast is in a typed-let RHS fires NUM-003 only once:

```nr
let y: i32 = x as i32;   // emits 1× NUM-003
print_int(x as i32);     // emits 2× NUM-003
```

## Severity

wrong-error: the diagnostic is *correct*, just duplicated. Doesn't
mislead the user about the bug, but adds noise that hides other warnings
in larger builds.

## Suspected location

NUM-003 emit site in the `as`-cast lowering / type-check. Add a per-site
"already-warned" set keyed on the AST node id (or the source span) so the
same cast can't emit twice across multiple type-check passes. Same shape
of fix used by other "warn once per node" diagnostics in the codebase
(grep `warned_set` / `diag_dedup`).
