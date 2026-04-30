---
title: TYP-005 ("undefined function") false-fires on closure-binding called from inside another closure body
severity: wrong-error
probe_file: probes/closures/closure_in_closure_no_braces.nr
diagnostic_actual: 'warning[TYP-005]: undefined function `inner()` at type-check time'
diagnostic_expected: clean compile — `let inner = |y| ...` followed by `inner(args)` is a callable closure binding, not a missing fn
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
---

## Repro (broken — TYP-005 fires)

```nr
fn main() -> i32 {
    let outer = |x: i32| { let inner = |y: i32| x + y; inner(100) };
    print_int(outer(7));
    0
}
```

Compile output:

```
warning[TYP-005]: undefined function `inner()` at type-check time (will fail at clang link if not a privatized cross-module fn). Check spelling, or import the rod that defines it.
  --> fn main@line 3:13
```

Plus the program returns `0` instead of `107` — but that's the
already-filed `closure-braced-body-returns-zero.md` silent-miscompute
finding compounding here. This finding is about the spurious TYP-005.

## Repro (works — same pattern outside a nested closure)

```nr
fn helper() -> i32 {
    let inner = |y: i32| y + 100;
    inner(7)   // <-- no TYP-005, returns 107
}

fn main() -> i32 {
    print_int(helper());
    0
}
```

Output: `107`, no TYP-005. So `let inner = ...; inner(...)` is fine
when the call site is in a regular fn body. The TYP-005 false-fire
specifically triggers when the call site is inside another closure's
body.

## Expected

Same behavior as the working repro. The type-checker's name-resolution
should look up `inner` in the closure's local scope (which has the
binding) before falling through to the "undefined function" diagnostic.

## Severity

wrong-error (warning, not hard error — the build still produces a
binary). But the diagnostic noise is misleading: users see
"undefined function" and chase a non-existent fn, when the real bug is
the silent-miscompute (also already filed).

## Suspected location

TYP-005 emit site in the call-expr type-check. The local scope walker
that resolves call targets probably stops at the enclosing fn boundary
and doesn't traverse the enclosing closure's local-binding table.
Add a closure-scope chain walk before the "undefined function" decision.

## Cross-ref

- `findings/inbox/2026-04-30-closure-braced-body-returns-zero.md` —
  the compounding silent-miscompute that produces the `0` output here.
- v0.4.146 (TYP-005 ext: closure called with wrong argc). Same TYP-005
  family.
