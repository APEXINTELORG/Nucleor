---
title: MATCH-002 ("unreachable arm after wildcard") false-fires when prior arm has a guard
severity: wrong-error
probe_file: probes/match/match_guards.nr
diagnostic_actual: 'warning[MATCH-002]: unreachable match arm after wildcard at arm 1 of 4'
diagnostic_expected: clean compile (no actual unreachable arm)
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
---

## Repro

```nr
fn classify(n: i32) -> i32 {
    match n {
        x if x < 0 => 0 - 1,    // arm 0: guarded
        0 => 0,                  // arm 1: literal
        x if x < 100 => 1,       // arm 2: guarded
        _ => 2,                  // arm 3: wildcard (last)
    }
}

fn main() -> i32 {
    print_int(classify(0 - 5));   // -1 ✓
    print_int(classify(0));       //  0 ✓
    print_int(classify(50));      //  1 ✓
    print_int(classify(500));     //  2 ✓
    0
}
```

## Actual

```
warning[MATCH-002]: unreachable match arm after wildcard at arm 1 of 4
  --> fn classify@line 2:5
```

…then the program runs and prints `-1, 0, 1, 2` — all correct
dispatches. So the **runtime behavior is right**; only the warning is
false.

The warning claims arm 1 (the literal `0` arm) is unreachable because
of a wildcard before it. But arm 0 is `x if x < 0`, which is a *guarded*
pattern — it only matches when `x < 0`, leaving `n == 0` reachable for
arm 1. The check appears to treat the unguarded `x` binder as a
wildcard for reachability analysis, ignoring the guard.

## Expected

Clean compile with no MATCH-002 warning. The guarded `x if ...` arm
does not act as a wildcard; arms after it remain reachable for cases
where the guard fails.

## Severity

wrong-error. Diagnostic noise on common idiom (guard arms before
literal/range/wildcard arms). Users seeing "unreachable after wildcard"
may delete the literal arm and accidentally drop coverage.

## Suspected location

The MATCH-002 reachability analysis. Grep candidates:
- `MATCH-002` literal in `compiler/nucleor_s1_compiler.nr`
- `is_wildcard_pattern` / `arm_is_catch_all` (if such helpers exist)

The check should treat a name-binding pattern as a catch-all *only when
the arm has no guard*. With a guard the pattern does not exhaust the
scrutinee space.

## Cross-ref

- v0.4.140 (MATCH-011: heterogeneous match arms — runtime SIGSEGV close).
  Same MATCH family, different mechanic.
